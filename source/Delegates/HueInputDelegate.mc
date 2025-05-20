import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application;
import Toybox.Time;

class HueRunnerInputDelegate extends WatchUi.BehaviorDelegate {

  private var _authService as HueAuthService?;
  // No longer need API client here

  function initialize() {
    BehaviorDelegate.initialize();
    _authService = new HueAuthService();
  }

  function onSelect() as Boolean {
    var app = getApp();
    var currentState = app.currentUiState;

    // This delegate now only handles initiating login
    if (currentState == STATE_LOGGED_OUT || currentState == STATE_ERROR) {
      System.println("Login button pressed. Initiating OAuth..."); // Keep existing comment
      if (_authService != null) {
        _authService.startAuthenticationFlow();
      }
    }
    return true;
  }

}