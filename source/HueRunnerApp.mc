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
    Application.Storage.clearValues();

    return [view, delegate];
  }

  function setInitialState() as Void {
    var accessToken = Storage.getValue(Constants.STORAGE_KEY_ACCESS_TOKEN);
    var expiresAt = Storage.getValue(Constants.STORAGE_KEY_EXPIRES_AT);
    var appKey = Storage.getValue(Constants.STORAGE_KEY_APP_KEY);

    if (accessToken != null && expiresAt != null && expiresAt > Time.now().value() && appKey != null) {
      currentUiState = STATE_LOGGED_IN;
    } else {
      Application.Storage.clearValues();
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
