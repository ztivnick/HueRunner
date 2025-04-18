import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Application;

class HueRunnerView extends WatchUi.View {
  private var _statusLabel as Text?;

  function initialize() {
    View.initialize();
  }

  function onLayout(dc as Dc) as Void {
    setLayout(Rez.Layouts.MainLayout(dc));
    _statusLabel = findDrawableById("statusLabel") as Text;
  }

  function onShow() as Void {
    WatchUi.requestUpdate();
  }

  function onUpdate(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
    dc.clear();
    var app = getApp();
    var currentState = app.currentUiState;
    var statusText = "";

    switch (currentState) {
      case STATE_LOGGED_OUT:
        statusText = "Login";
        break;
      case STATE_LOGGING_IN:
        statusText = "Logging In...";
        break;
      case STATE_LOGGED_IN:
        statusText = "Logged In";
        break;
      case STATE_ERROR:
        statusText = "Error\nTap to Retry";
        break;
      default:
        statusText = "Unknown State";
        break;
    }

    if (_statusLabel != null) {
      _statusLabel.setText(statusText);
    }

    View.onUpdate(dc);
  }

  function onHide() as Void {}
}
