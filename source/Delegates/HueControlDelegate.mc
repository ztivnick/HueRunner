import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application;

class HueControlDelegate extends WatchUi.BehaviorDelegate {

    private var _lightIsOn as Boolean = false; // TODO: Initialize based on actual state later
    private var _apiClient as HueApiClient?;

    function initialize() {
        BehaviorDelegate.initialize();
        _apiClient = new HueApiClient();
        // TODO: Fetch initial light state here?
    }

    // Handle primary action: toggle the light
    function onSelect() as Boolean {
        System.println("Control View Select: toggling light state");
        if (_apiClient != null) {
            _lightIsOn = !_lightIsOn;
            _apiClient.setLightState(Secrets.TARGET_LIGHT_ID, _lightIsOn, method(:onLightCommandResponse));
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // TODO: Implement onMenu, onSwipe, etc. for future features (change target, brightness...)

    // Handles response from the API client for light commands
    private function onLightCommandResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Light Command Response Received in Control Delegate. HTTP Code: " + responseCode);
        var app = getApp();

        if (data != null) {
            System.println("Light Command Response Data: " + data);
        } else {
            System.println("Light Command Response data is null.");
        }

        if (responseCode >= 200 && responseCode < 300) {
             System.println("Light command likely successful.");
        } else {
            System.println("Light command failed. Code: " + responseCode);
            _lightIsOn = !_lightIsOn;

            if (responseCode == 401 || responseCode == 403) {
                System.println("Authentication/Authorization Error.");
                Application.Storage.clearValues();
                app.setUiState(STATE_ERROR);
                WatchUi.popView(WatchUi.SLIDE_DOWN);
            } else {
                 System.println("Generic API error occurred.");
            }
        }
    }
}