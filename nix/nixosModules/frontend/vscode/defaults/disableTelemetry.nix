# disable telemetry for vscode
# including for extensions which may be installed (that's why this is always set globally)
# TODO extract & upstream
{
  # _class = "homeManager.vscodeProfile";
  userSettings = {

    "extensions.ignoreRecommendations" = true;

    "npm.fetchOnlinePackageInfo" = false;

    "redhat.telemetry.enabled" = false;

    "telemetry.telemetryLevel" = "off";

    "vsicons.dontShowNewVersionMessage" = true;

  };
}
