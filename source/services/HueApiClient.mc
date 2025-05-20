import Toybox.Lang;
import Toybox.Communications;
import Toybox.Application;
import Toybox.Time;
import Toybox.StringUtil;

class HueApiClient {
  function initialize() {}

  function setLightState(lightId as String, onState as Boolean, callback as Method) as Void {
    var endpoint = "/light/" + lightId;
    var body = { "on" => { "on" => onState } };
    _makeApiRequest(Communications.HTTP_REQUEST_METHOD_PUT, endpoint, body, callback);
  }

  private function _makeApiRequest(
    httpMethod as Communications.HttpRequestMethod,
    endpoint as String,
    body as Dictionary?,
    callback as Method
  ) as Void {
    var accessToken = Application.Storage.getValue(Constants.STORAGE_KEY_ACCESS_TOKEN) as String?;
    var appKey = Application.Storage.getValue(Constants.STORAGE_KEY_APP_KEY) as String?;
    var expiresAt = Application.Storage.getValue(Constants.STORAGE_KEY_EXPIRES_AT) as Number?;

    if (accessToken == null || appKey == null || expiresAt == null) {
      System.println("Error: Missing credentials/expiry for API call.");
      Application.Storage.clearValues();
      getApp().setUiState(STATE_ERROR);
      return;
    }

    // 60 seconds to allow for some buffer
    if (Time.now().value() >= expiresAt - 60) {
      System.println("Access token expired or nearing expiry. Attempting refresh...");
      _refreshToken();
      return;
    }

    var url = Constants.HUE_API_V2_RESOURCE_BASE + endpoint;

    System.println("API Request: " + httpMethod + " " + url);

    var headers = {
      "Authorization" => "Bearer " + accessToken,
      "hue-application-key" => appKey,
      "Accept" => "application/json",
    };
    if (body != null) {
      headers["Content-Type"] = Communications.REQUEST_CONTENT_TYPE_JSON;
    }

    var options = {
      :method => httpMethod,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(url, body, options, callback);
  }

  private function _refreshToken() as Void {
    var refreshToken = Application.Storage.getValue(Constants.STORAGE_KEY_REFRESH_TOKEN) as String?;

    if (refreshToken == null) {
      System.println("Error: Missing refresh token. Cannot refresh.");
      Application.Storage.clearValues();
      getApp().setUiState(STATE_ERROR);
      return;
    }

    System.println("Attempting token refresh using refresh token...");

    var idSecret = Secrets.HUE_CLIENT_ID + ":" + Secrets.HUE_CLIENT_SECRET;
    var base64IdSecret = StringUtil.encodeBase64(idSecret);
    var authHeader = "Basic " + base64IdSecret;

    var headers = {
      "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
      "Authorization" => authHeader,
    };

    var body = {
      "grant_type" => "refresh_token",
      "refresh_token" => refreshToken,
    };

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => headers,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(Constants.HUE_TOKEN_URL, body, options, method(:onTokenRefreshResponse));
  }

  function onTokenRefreshResponse(responseCode as Number, data as Dictionary?) as Void {
    System.println("Token Refresh Response Received. HTTP Code: " + responseCode);

    if (responseCode == 200 && data != null) {
      var newAccessToken = data["access_token"];
      var newRefreshToken = data["refresh_token"];
      var newExpiresIn = data["expires_in"];

      if (newAccessToken != null && newRefreshToken != null && newExpiresIn != null) {
        var newExpiresAt = Time.now().value() + newExpiresIn;

        System.println("Token refresh successful. Storing new tokens.");
        Application.Storage.setValue(Constants.STORAGE_KEY_ACCESS_TOKEN, newAccessToken);
        Application.Storage.setValue(Constants.STORAGE_KEY_REFRESH_TOKEN, newRefreshToken);
        Application.Storage.setValue(Constants.STORAGE_KEY_EXPIRES_AT, newExpiresAt);
      } else {
        System.println("Error: Missing data in successful token refresh response.");
        Application.Storage.clearValues();
        getApp().setUiState(STATE_ERROR);
      }
    } else {
      System.println("Token Refresh Failed. Code: " + responseCode);
      if (data != null) {
        System.println("Refresh Error Data: " + data);
      }
      Application.Storage.clearValues();
      getApp().setUiState(STATE_ERROR);
    }
  }
}
