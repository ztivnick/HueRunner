import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.Time;

enum UiState {
  STATE_LOGGED_OUT,
  STATE_LOGGING_IN,
  STATE_LOGGED_IN,
  STATE_ERROR,
}

class HueRunnerApp extends Application.AppBase {
  var currentUiState as UiState = STATE_LOGGED_OUT;

  function initialize() {
    AppBase.initialize();
    setInitialState();
  }

  function onStart(state as Dictionary?) as Void {}

  function onStop(state as Dictionary?) as Void {}

  function getInitialView() as [Views] or [Views, InputDelegates] {
    var view = new HueRunnerView();
    var delegate = new HueRunnerInputDelegate();
    return [view, delegate];
  }

  function setInitialState() as Void {
    var accessToken = Storage.getValue("hue_access_token");
    var expiresAt = Storage.getValue("hue_token_expires_at");
    var appKey = Storage.getValue("hue_app_key");

    if (accessToken != null && expiresAt != null && expiresAt > Time.now().value() && appKey != null) {
      currentUiState = STATE_LOGGED_IN;
    } else {
      Storage.deleteValue("hue_access_token");
      Storage.deleteValue("hue_refresh_token");
      Storage.deleteValue("hue_token_expires_at");
      Storage.deleteValue("hue_app_key");
      currentUiState = STATE_LOGGED_OUT;
    }
  }

  function setUiState(newState as UiState) as Void {
    currentUiState = newState;
    WatchUi.requestUpdate();
  }
}

function getApp() as HueRunnerApp {
  return Application.getApp() as HueRunnerApp;
}
