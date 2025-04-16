import Toybox.Lang;
import Toybox.Communications;
import Toybox.Application;
import Toybox.System;
import Toybox.Time;
import Toybox.StringUtil;
import Toybox.Math;

class HueAuthService {
  private var _oauthState as String?;

  function initialize() {
    Communications.registerForOAuthMessages(method(:onOAuthMessageCallback));
  }

  function startAuthenticationFlow() as Void {
    var app = getApp();

    app.setUiState(STATE_LOGGING_IN);
    _initiateOAuth();
  }

  // Step 1: Initiate OAuth Code Flow
  private function _initiateOAuth() as Void {
    Math.srand(System.getTimer());
    _oauthState = Constants.OAUTH_STATE_PREFIX + Math.rand();

    var params = {
      "client_id" => Secrets.HUE_CLIENT_ID,
      "response_type" => "code",
      "state" => _oauthState,
      "redirect_uri" => Constants.REDIRECT_URI,
    };

    var resultKeys = {
      "code" => "code",
      "state" => "state",
      "error" => "error",
      "error_description" => "error_description",
    };

    Communications.makeOAuthRequest(
      Constants.HUE_AUTH_URL,
      params,
      Constants.REDIRECT_URI,
      Communications.OAUTH_RESULT_TYPE_URL,
      resultKeys
    );
  }

  // Step 2: Handle OAuth Redirect (Callback for makeOAuthRequest)
  function onOAuthMessageCallback(message as Communications.OAuthMessage) as Void {
    System.println("OAuth Message Received:");
    System.println("  Data: " + message.data);
    var app = getApp();
    if (message.data != null) {
      if (message.data["error"]) {
        System.println("OAuth Error from Hue: " + message.data["error"]);
        app.setUiState(STATE_ERROR);
        _oauthState = null;
        return;
      }
      if (message.data["code"] && message.data["state"]) {
        var receivedCode = message.data["code"];
        var receivedState = message.data["state"];
        if (_oauthState == null || !_oauthState.equals(receivedState)) {
          System.println("OAuth state mismatch");
          app.setUiState(STATE_ERROR);
          _oauthState = null;
          return;
        }
        _oauthState = null;
        System.println("OAuth success, received auth code.");
        _exchangeCodeForTokens(receivedCode);
        return;
      }
    }
    System.println("OAuth Message Data null or incomplete.");
    app.setUiState(STATE_ERROR);
    _oauthState = null;
  }

  // Step 3: Exchange Code for Tokens
  private function _exchangeCodeForTokens(code as String) as Void {
    System.println("Exchanging code for tokens...");
    var idSecret = Secrets.HUE_CLIENT_ID + ":" + Secrets.HUE_CLIENT_SECRET;
    var base64IdSecret = StringUtil.encodeBase64(idSecret);
    var authHeader = "Basic " + base64IdSecret;
    var headers = { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED, "Authorization" => authHeader };
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };
    var body = { "grant_type" => "authorization_code", "code" => code };

    Communications.makeWebRequest(Constants.HUE_TOKEN_URL, body, options, method(:onTokenResponseCallback));
  }

  // Step 4: Handle Token Response (Callback for token request)
  function onTokenResponseCallback(responseCode as Number, data as Dictionary?) as Void {
    System.println("Token Response Received. HTTP Code: " + responseCode);
    var app = getApp();

    if (responseCode == 200 && data != null) {
      var accessToken = data["access_token"];
      var refreshToken = data["refresh_token"];
      var expiresIn = data["expires_in"];
      if (accessToken != null && refreshToken != null && expiresIn != null) {
        var expiresAt = Time.now().value() + expiresIn;
        System.println("Access token received. Storing tokens.");
        Application.Storage.setValue(Constants.STORAGE_KEY_ACCESS_TOKEN, accessToken);
        Application.Storage.setValue(Constants.STORAGE_KEY_REFRESH_TOKEN, refreshToken);
        Application.Storage.setValue(Constants.STORAGE_KEY_EXPIRES_AT, expiresAt);
        System.println("Triggering remote link button press...");
        _pressLinkButton(accessToken);
        return;
      } else {
        System.println("Error: Missing token data in response.");
      }
    } else {
      System.println("Token Request Failed. Code: " + responseCode);
      if (data != null) {
        System.println("Error Data: " + data);
      }
    }

    app.setUiState(STATE_ERROR);
  }

  // Step 5: Press Link Button via API
  private function _pressLinkButton(accessToken as String) as Void {
    var url = Constants.HUE_ROUTE_BASE + "/api/0/config";
    var bodyDict = { "linkbutton" => true };
    var headers = {
      "Authorization" => "Bearer " + accessToken,
      "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      "Accept" => "application/json",
    };
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_PUT,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };
    System.println("Sending Link Button command to " + url);
    Communications.makeWebRequest(url, bodyDict, options, method(:onLinkButtonResponse));
  }

  // Step 6: Handle Link Button Response (Callback)
  function onLinkButtonResponse(responseCode as Number, data as Dictionary?) as Void {
    System.println("Link Button Response Received. HTTP Code: " + responseCode);
    var app = getApp();

    if (responseCode == 200) {
      System.println("Link button command seems successful. Proceeding to create username.");
      var accessToken = Application.Storage.getValue(Constants.STORAGE_KEY_ACCESS_TOKEN) as String?;
      if (accessToken != null) {
        _createRemoteUsername(accessToken);
        return;
      } else {
        System.println("Error: Access token missing before creating username.");
      }
    } else {
      System.println("Link button command failed. Code: " + responseCode);
      if (data != null) {
        System.println("Link Button Error Data: " + data);
      }
    }

    app.setUiState(STATE_ERROR);
  }

  // Step 7: Create Remote Username/App Key
  private function _createRemoteUsername(accessToken as String) as Void {
    var url = Constants.HUE_ROUTE_BASE + "/api";
    var bodyDict = { "devicetype" => Constants.HUE_APP_NAME };
    var headers = {
      "Authorization" => "Bearer " + accessToken,
      "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      "Accept" => "application/json",
    };
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };
    System.println("Sending Create Username command to " + url);
    Communications.makeWebRequest(url, bodyDict, options, method(:onUsernameResponse));
  }

  // Step 8: Handle Create Username Response (Callback)
  function onUsernameResponse(responseCode as Number, data as Lang.Dictionary?) as Void {
    // Data is Array
    System.println("Create Username Response Received. HTTP Code: " + responseCode);
    var app = getApp();

    // Parse expected structure: [{"success":{"username":"..."}}]
    if (responseCode == 200 && data != null && data.size() > 0) {
      var responseItem = data[0];
      if (responseItem instanceof Toybox.Lang.Dictionary && responseItem["success"]) {
        var successData = responseItem["success"];
        if (successData instanceof Toybox.Lang.Dictionary && successData["username"]) {
          var username = successData["username"] as String?;
          if (username != null) {
            System.println("Username/App Key received.");
            Application.Storage.setValue(Constants.STORAGE_KEY_APP_KEY, username);
            System.println("Username/App Key stored successfully!");
            app.setUiState(STATE_LOGGED_IN);
            return;
          }
        }
      }
    }

    System.println("Create Username command failed or response invalid. Code: " + responseCode);
    if (data != null) {
      System.println("Create Username Error Data: " + data);
    }
    Application.Storage.clearValues();
    app.setUiState(STATE_ERROR);
  }
}
