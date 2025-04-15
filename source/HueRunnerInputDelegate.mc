import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Communications;
import Toybox.Math;
import Toybox.Application;
import Toybox.Time;

class HueRunnerInputDelegate extends WatchUi.BehaviorDelegate {
  // API constants
  private const HUE_AUTH_URL = "https://api.meethue.com/v2/oauth2/authorize";
  private const HUE_TOKEN_URL = "https://api.meethue.com/v2/oauth2/token";
  private const HUE_ROUTE_BASE = "https://api.meethue.com/route";
  private const HUE_CLIENT_ID = Secrets.HUE_CLIENT_ID;
  private const HUE_CLIENT_SECRET = Secrets.HUE_CLIENT_SECRET;
  private const REDIRECT_URI = "https://localhost";
  private const OAUTH_STATE_PREFIX = "HueRunnerState_";
  private const HUE_APP_NAME = Application.Properties.getValue("AppName");

  private const TARGET_LIGHT_ID = "375f7121-afad-47b0-9cbc-8052ad030cac";

  // Storage constants
  private const STORAGE_KEY_ACCESS_TOKEN = "hue_access_token";
  private const STORAGE_KEY_REFRESH_TOKEN = "hue_refresh_token";
  private const STORAGE_KEY_EXPIRES_AT = "hue_token_expires_at";
  private const STORAGE_KEY_APP_KEY = "hue_app_key";

  private var _oauthState as String?;

  function initialize() {
    BehaviorDelegate.initialize();

    Communications.registerForOAuthMessages(method(:onOAuthMessageCallback));
  }

  function onSelect() as Boolean {
    var app = getApp();
    var currentState = app.currentUiState;

    if (currentState == STATE_LOGGED_OUT || currentState == STATE_ERROR) {
      System.println("Login button pressed. Initiating OAuth...");
      app.setUiState(STATE_LOGGING_IN);
      /**
       * Steps for Auth:
       * (1) initiateOAuth(): Prompt user to login to Hue with OAuth
       * (2) onOAuthMessageCallback(): Callback that takes auth code and start token process
       * (3) exchangeCodeForTokens(): Forms request with auth code, client id, and client secret to get auth token
       * (4) onTokenResponseCallback(): Callback that takes auth token and stores on device with expiration and refresh info
       **/
      initiateOAuth();
    } else if (currentState == STATE_LOGGED_IN) {
      System.println("Logged in - trying to turn light on");
      var accessToken = Application.Storage.getValue(STORAGE_KEY_ACCESS_TOKEN) as String?;
      if (accessToken != null) {
        sendLightCommand(accessToken, false);
      }
    }

    return true;
  }

  function sendLightCommand(accessToken as String, onState as Boolean) as Void {
    var appKey = Application.Storage.getValue(STORAGE_KEY_APP_KEY) as String?;

    // Check if app key exists (should if state is LOGGED_IN)
    if (appKey == null) {
      System.println("Error: Missing App Key for API call.");
      getApp().setUiState(STATE_ERROR);
      return;
    }

    var url = HUE_ROUTE_BASE + "/clip/v2/resource/light/" + TARGET_LIGHT_ID;

    var bodyDict = {
      "on" => {
        "on" => onState,
      },
    };

    System.println("Using Access Token (first 10 chars): " + accessToken.substring(0, 10) + "...");
    System.println("Using App Key (first 10 chars): " + appKey.substring(0, 10) + "...");

    System.println("Sending Hue Command: " + bodyDict + " to " + url);

    var headers = {
      "Authorization" => "Bearer " + accessToken,
      "hue-application-key" => appKey,
      "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      "Accept" => "application/json",
    };

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_PUT,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(url, bodyDict, options, method(:onLightCommandResponse));
  }

  function onLightCommandResponse(responseCode as Number, data as String?) as Void {
    System.println("Light Command Response Received. HTTP Code: " + responseCode);

    var app = getApp();

    if (responseCode >= 200 && responseCode < 300) {
      System.println("Light command likely successful (HTTP " + responseCode + ").");
    } else {
      System.println("Light command failed. Code: " + responseCode);

      if (responseCode == 401 || responseCode == 403) {
        System.println("Authentication/Authorization Error - Token might be expired or invalid.");
        Application.Storage.clearValues();
        app.setUiState(STATE_ERROR);
      } else {
        System.println("Generic API error occurred.");
      }
    }
  }

  function initiateOAuth() as Void {
    Math.srand(System.getTimer());
    _oauthState = OAUTH_STATE_PREFIX + Math.rand();

    var params = {
      "client_id" => HUE_CLIENT_ID,
      "response_type" => "code",
      "state" => _oauthState,
      "redirect_uri" => REDIRECT_URI,
    };

    var resultKeys = {
      "code" => "code",
      "state" => "state",
      "error" => "error",
      "error_description" => "error_description",
    };

    Communications.makeOAuthRequest(
      HUE_AUTH_URL,
      params,
      REDIRECT_URI,
      Communications.OAUTH_RESULT_TYPE_URL,
      resultKeys
    );
  }

  function onOAuthMessageCallback(message as Communications.OAuthMessage) as Void {
    System.println("OAuth Message Received:");
    System.println("  Response Code: " + message.responseCode);
    System.println("  Data: " + message.data);

    var app = getApp();

    if (message.data != null) {
      if (message.data["error"]) {
        var error = message.data["error"];
        var errorDesc = message.data["error_description"];
        System.println("OAuth Error from Hue: " + error + " - " + errorDesc);
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

        // All is good, get access token
        System.println("OAuth success, received auth code: " + receivedCode);
        exchangeCodeForTokens(receivedCode);
      } else {
        System.println("OAuth Success but missing code or state in data.");
        app.setUiState(STATE_ERROR);
        _oauthState = null;
      }
    } else {
      System.println("OAuth Message Data is null.");
      app.setUiState(STATE_ERROR);
      _oauthState = null;
    }
  }

  function exchangeCodeForTokens(code as String) as Void {
    System.println("Exchanging code for tokens...");

    var idSecret = HUE_CLIENT_ID + ":" + HUE_CLIENT_SECRET;
    var base64IdSecret = StringUtil.encodeBase64(idSecret);
    var authHeader = "Basic " + base64IdSecret;

    var headers = {
      "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
      "Authorization" => authHeader,
    };

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    var body = {
      "grant_type" => "authorization_code",
      "code" => code,
    };

    Communications.makeWebRequest(HUE_TOKEN_URL, body, options, method(:onTokenResponseCallback));
  }

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
        Application.Storage.setValue(STORAGE_KEY_ACCESS_TOKEN, accessToken);
        Application.Storage.setValue(STORAGE_KEY_REFRESH_TOKEN, refreshToken);
        Application.Storage.setValue(STORAGE_KEY_EXPIRES_AT, expiresAt);

        System.println("Triggering remote link button press...");
        pressLinkButton(accessToken);
      } else {
        System.println("Error: Missing token data in response.");
        app.setUiState(STATE_ERROR);
      }
    } else {
      System.println("Token Request Failed. Code: " + responseCode);
      if (data != null) {
        System.println("Error Data: " + data);
      }
      app.setUiState(STATE_ERROR);
    }
  }

  function pressLinkButton(accessToken as String) as Void {
    var url = HUE_ROUTE_BASE + "/api/0/config";

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

  function onLinkButtonResponse(responseCode as Number, data as Dictionary?) as Void {
    System.println("Link Button Response Received. HTTP Code: " + responseCode);
    var app = getApp();

    if (responseCode == 200 && data != null && data instanceof Toybox.Lang.Array) {
      System.println("Link button command seems successful. Proceeding to create username.");

      var accessToken = Application.Storage.getValue(STORAGE_KEY_ACCESS_TOKEN) as String?;
      if (accessToken != null) {
        createRemoteUsername(accessToken);
      } else {
        System.println("Error: Access token missing before creating username.");
        app.setUiState(STATE_ERROR);
      }
      return;
    }

    System.println("Link button command failed. Code: " + responseCode);
    if (data != null) {
      System.println("Link Button Error Data: " + data);
    }
    app.setUiState(STATE_ERROR);
  }

  function createRemoteUsername(accessToken as String) as Void {
    var url = HUE_ROUTE_BASE + "/api";

    var bodyDict = { "devicetype" => HUE_APP_NAME };

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

  function onUsernameResponse(responseCode as Number, data as Dictionary?) as Void {
    System.println("Create Username Response Received. HTTP Code: " + responseCode);
    var app = getApp();

    if (responseCode == 200 && data != null && data instanceof Toybox.Lang.Array && data.size() > 0) {
      var responseItem = data[0];
      if (responseItem instanceof Toybox.Lang.Dictionary && responseItem.hasKey("success")) {
        var successData = responseItem["success"];
        if (successData instanceof Toybox.Lang.Dictionary && successData.hasKey("username")) {
          var username = successData["username"] as String?;
          if (username != null) {
            System.println("Username/App Key received: " + username);
            Application.Storage.setValue(STORAGE_KEY_APP_KEY, username);
            System.println("Username/App Key stored successfully!");
            app.setUiState(STATE_LOGGED_IN);
            return;
          }
        }
      }
    }

    System.println("Create Username command failed. Code: " + responseCode);
    if (data != null) {
      System.println("Create Username Error Data: " + data);
    }
    // Clear stored tokens if this final registration step fails
    Application.Storage.deleteValue(STORAGE_KEY_ACCESS_TOKEN);
    Application.Storage.deleteValue(STORAGE_KEY_REFRESH_TOKEN);
    Application.Storage.deleteValue(STORAGE_KEY_EXPIRES_AT);
    Application.Storage.deleteValue(STORAGE_KEY_APP_KEY);
    app.setUiState(STATE_ERROR);
  }
}
