import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Communications;
import Toybox.Math;
import Toybox.Application.Properties;

class HueRunnerInputDelegate extends WatchUi.BehaviorDelegate {
  // Request constants
  private const HUE_AUTH_URL = "https://api.meethue.com/v2/oauth2/authorize";
  private const HUE_TOKEN_URL = "https://api.meethue.com/v2/oauth2/token";
  private const HUE_CLIENT_ID = Secrets.HUE_CLIENT_ID;
  private const HUE_CLIENT_SECRET = Secrets.HUE_CLIENT_SECRET;
  private const REDIRECT_URI = "https://localhost";
  private const OAUTH_STATE_PREFIX = "HueRunnerState_";

  // Storage constants
  private const STORAGE_KEY_ACCESS_TOKEN = "hue_access_token";
  private const STORAGE_KEY_REFRESH_TOKEN = "hue_refresh_token";
  private const STORAGE_KEY_EXPIRES_AT = "hue_token_expires_at";

  private var _oauthState as String?;

  function initialize() {
    BehaviorDelegate.initialize();

    Communications.registerForOAuthMessages(method(:onOAuthMessageCallback));
  }

  function onSelect() as Boolean {
    System.println("Login button pressed! Initiating OAuth...");

    if (isLoggedIn()) {
      System.println("Already logged in.");
      return true;
    }

    /**
     * Steps for Auth:
     * (1) initiateOAuth(): Prompt user to login to Hue with OAuth
     * (2) onOAuthMessageCallback(): Callback that takes auth code and start token process
     * (3) exchangeCodeForTokens(): Forms request with auth code, client id, and client secret to gets auth token
     * (4) onTokenResponseCallback(): Callback that takes auth token and stores on device with expiration and refresh info
     **/
    initiateOAuth();

    return true;
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

    if (message.data != null) {
      if (message.data["error"]) {
        var error = message.data["error"];
        var errorDesc = message.data["error_description"];
        System.println("OAuth Error from Hue: " + error + " - " + errorDesc);
        // TODO: Update UI - Show error message
        _oauthState = null;
        return;
      }

      if (message.data["code"] && message.data["state"]) {
        var receivedCode = message.data["code"];
        var receivedState = message.data["state"];

        if (_oauthState == null || !_oauthState.equals(receivedState)) {
          System.println("OAuth state mismatch");
          // TODO: Update UI - Show error message
          _oauthState = null;
          return;
        }

        // All is good, get access token
        System.println("OAuth success, received auth code: " + receivedCode);
        exchangeCodeForTokens(receivedCode);
      } else {
        System.println("OAuth Success but missing code or state in data.");
        // TODO: Update UI - Show error message
        _oauthState = null;
      }
    } else {
      System.println("OAuth Message Data is null.");
      // TODO: Update UI - Show error message
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

    var params = {
      "grant_type" => "authorization_code",
      "code" => code,
    };

    Communications.makeWebRequest(HUE_TOKEN_URL, params, options, method(:onTokenResponseCallback));
    // TODO: Update UI - Getting access token
  }

  function onTokenResponseCallback(responseCode as Number, data as Dictionary?) as Void {
    System.println("Token Response Received. HTTP Code: " + responseCode);

    if (responseCode == 200) {
      if (data != null) {
        System.println("Token Success! Data: " + data);
        var accessToken = data["access_token"];
        var refreshToken = data["refresh_token"];
        var expiresIn = data["expires_in"];

        if (accessToken != null && refreshToken != null && expiresIn != null) {
          var expiresAt = Time.now().value() + expiresIn;

          Application.Storage.setValue(STORAGE_KEY_ACCESS_TOKEN, accessToken);
          Application.Storage.setValue(STORAGE_KEY_REFRESH_TOKEN, refreshToken);
          Application.Storage.setValue(STORAGE_KEY_EXPIRES_AT, expiresAt);

          System.println("Tokens stored successfully!");
          // TODO: Update UI - "Login Successful!" or navigate to main control view
        } else {
          System.println("Error: Missing token data in response.");
          // TODO: Update UI - Show "Login Failed (Data Error)"
        }
      } else {
        System.println("Error: Token response data is null.");
        // TODO: Update UI - Show "Login Failed (No Data)"
      }
    } else {
      System.println("Token Request Failed. Error Code: " + responseCode);
      if (data != null) {
        System.println("Error Data: " + data);
      }
      // TODO: Update UI - Show "Login Failed"
      Application.Storage.clearValues();
    }
  }

  function isLoggedIn() as Boolean {
    var accessToken = Application.Storage.getValue(STORAGE_KEY_ACCESS_TOKEN);
    var expiresAt = Application.Storage.getValue(STORAGE_KEY_EXPIRES_AT);
    return accessToken != null && expiresAt != null && expiresAt > Time.now().value();
  }
}
