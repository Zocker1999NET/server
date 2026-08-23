{
  self,
  lib,
  ...
}:
{
  _class = "flake";
  perSystem =
    { pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.strings) escapeNixString;
      inherit (pkgs.testers) runNixOSTest;

      # these texts should be different to avoid false positives in the tests
      pageFileName = "test-page.html";
      pageTitle = "Quuxley Zornifax"; # mind width of tab bar so everything fits
      pageBody = "Lorem ipsum dolor sit amet."; # mind maximum width of HTML content so text does not wrap
    in
    {
      # This test tests following capabilities of Firefox / fontconfig:
      # 1. rendering content of simple HTML pages (i.e. HTML body)
      #    (less likely to fail -> tested first)
      # 2. rendering text in the url bar
      # 3. rendering page title in the tab bar
      #    (preventing regression of https://github.com/NixOS/nixpkgs/issues/540847)
      checks.firefox-render = runNixOSTest {
        name = "firefox-render";
        imports = [
          self.modules.nixosTest._default
        ];
        nodes.machine =
          {
            config,
            modulesPath,
            pkgs,
            ...
          }:
          let
            script = pkgs.writeShellApplication {
              name = "firefox-render-test";
              text = ''
                # ensure resolution is large enough so all required text is visible
                ${getExe pkgs.wlr-randr} --output Virtual-1 --mode 1360x768 --scale 1.3
                /usr/bin/env firefox file:///etc/${pageFileName}
              '';
            };
          in
          {
            imports = [
              "${modulesPath}/../tests/common/wayland-cage.nix"
            ];

            programs.firefox.enable = true;

            services.cage.program = getExe script;

            # pageTitle must not appear in the body (for 3.)
            environment.etc.${pageFileName}.source = pkgs.writeText pageFileName ''
              <!DOCTYPE html>
              <html>
                <head><title>${pageTitle}</title></head>
                <body>
                  <p>${pageBody}</p>
                </body>
              </html>
            '';
          };
        enableOCR = true;
        testScript = ''
          @polling_condition
          def firefox_running():
            "check that firefox is running"
            machine.succeed("pgrep -x firefox")

          machine.wait_for_unit("graphical.target")

          with subtest("0. Firefox is launched & running"):
            firefox_running.wait()

          with firefox_running:
            with subtest("1. Firefox renders the page body"):
              # give cage & Firefox some time to fully open
              machine.wait_for_text(${escapeNixString pageBody})

            # make screenshot after page is fully loaded to avoid black screenshots
            machine.screenshot("firefox-page")

            # further timeouts are shorter as page should be fully loaded by now

            with subtest("2. Firefox renders text in url bar"):
              machine.wait_for_text(${escapeNixString pageFileName}, timeout=20)

            with subtest("3. Firefox renders the page title in tab bar"):
              machine.wait_for_text(${escapeNixString pageTitle}, timeout=20)
        '';
      };
    };
}
