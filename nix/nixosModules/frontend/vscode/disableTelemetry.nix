# disable telemetry for vscode
# including for extensions which may be installed (that's why this is always set globally)
# TODO extract & upstream
{
  # _class = "homeManager.vscodeProfile";
  userSettings = {

    "redhat.telemetry.enabled" = false;

    "telemetry.telemetryLevel" = "off";

  };
}
