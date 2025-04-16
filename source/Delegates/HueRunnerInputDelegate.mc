import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application;
import Toybox.Time;

using Toybox.Application.Storage;
using Toybox.System;
using Toybox.WatchUi;

class HueRunnerInputDelegate extends WatchUi.BehaviorDelegate {
  private var _lightIsOn as Boolean = false;

  private var _authService as HueAuthService?;
  private var _apiClient as HueApiClient?;

  function initialize() {
    BehaviorDelegate.initialize();
    _authService = new HueAuthService();
    _apiClient = new HueApiClient();
  }

  function onSelect() as Boolean {
    var app = getApp();
    var currentState = app.currentUiState;

    if (currentState == STATE_LOGGED_OUT || currentState == STATE_ERROR) {
      if (_authService != null) {
        _authService.startAuthenticationFlow();
      }
    } else if (currentState == STATE_LOGGED_IN) {
      System.println("Logged in - toggling light state");
      if (_apiClient != null) {
        _lightIsOn = !_lightIsOn;
        _apiClient.setLightState(Secrets.TARGET_LIGHT_ID, _lightIsOn, method(:onLightCommandResponse));
      }
    }
    return true;
  }

  function onLightCommandResponse(responseCode as Number, data as Dictionary?) as Void {
    System.println("Light Command Response Received in Delegate. HTTP Code: " + responseCode);
    var app = getApp();

    if (data != null) {
      System.println("Light Command Response Data: " + data);
    } else {
      System.println("Light Command Response data is null.");
    }

    if (responseCode >= 200 && responseCode < 300) {
    } else {
      System.println("Light command failed. Code: " + responseCode);
      _lightIsOn = !_lightIsOn;

      if (responseCode == 401 || responseCode == 403) {
        System.println("Authentication/Authorization Error.");
        Application.Storage.clearValues();
        app.setUiState(STATE_ERROR);
      } else {
        System.println("Generic API error occurred.");
      }
    }
  }
}
