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

  // Called when this View is brought to the foreground. Restore
  // the state of this View and prepare it to be shown. This includes
  // loading resources into memory.
  function onShow() as Void {
    WatchUi.requestUpdate();
  }

  // Update the view
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
        statusText = "Something went wrong, try restarting your watch";
        break;
    }

    if (_statusLabel != null) {
      _statusLabel.setText(statusText);
    }

    View.onUpdate(dc);
  }

  // Called when this View is removed from the screen. Save the
  // state of this View here. This includes freeing resources from
  // memory.
  function onHide() as Void {}
}
