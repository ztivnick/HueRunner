import Toybox.Lang;

module Constants {
    // API constants
    const HUE_AUTH_URL = "https://api.meethue.com/v2/oauth2/authorize";
    const HUE_TOKEN_URL = "https://api.meethue.com/v2/oauth2/token";
    const HUE_ROUTE_BASE = "https://api.meethue.com/route";
    const HUE_API_V2_RESOURCE_BASE = HUE_ROUTE_BASE + "/clip/v2/resource";
    const HUE_APP_NAME = "Huerunner";
    const REDIRECT_URI = "https://localhost";
    const OAUTH_STATE_PREFIX = "HueRunnerState_";

    // Storage constants
    const STORAGE_KEY_ACCESS_TOKEN = "hue_access_token";
    const STORAGE_KEY_REFRESH_TOKEN = "hue_refresh_token";
    const STORAGE_KEY_EXPIRES_AT = "hue_token_expires_at";
    const STORAGE_KEY_APP_KEY = "hue_app_key";
}