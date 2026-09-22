cask "chromium" do
  arch arm: "Mac_Arm", intel: "Mac"

  version :latest
  sha256 :no_check

  url "https://download-chromium.appspot.com/dl/#{arch}?type=snapshots"
  name "Chromium"
  desc "Free and open-source web browser"
  homepage "https://www.chromium.org/Home"

  conflicts_with cask: "ungoogled-chromium"
  depends_on macos: :ventura

  app "chrome-mac/Chromium.app"
  # Embed the tap asset before entering the sandbox. Installed cask copies do not
  # live beside Resources, and the step runner must only read staged files.
  icon = ((cask.tap || Tap.fetch("zubb/tap")).path/"Resources/google-chrome-for-testing.icns").binread
  generated_script "stage-custom-icon.sh", content: <<~SH
    #!/bin/sh
    set -eu
    /usr/bin/base64 -D > "$1" <<'ICON'
    #{[icon].pack("m0")}
    ICON
  SH
  command_wrapper "chromium", executable: "#{appdir}/Chromium.app/Contents/MacOS/Chromium"

  postflight_steps do
    run "/usr/bin/plutil",
        args: ["-replace", "LSEnvironment.GOOGLE_API_KEY", "-string",
               "AIzaSyCkfPOPZXDKNn8hhgu3JrA62wIgC93d44k", "{{appdir}}/Chromium.app/Contents/Info.plist"]
    run "/usr/bin/plutil",
        args: ["-replace", "LSEnvironment.GOOGLE_DEFAULT_CLIENT_ID", "-string",
               "811574891467.apps.googleusercontent.com", "{{appdir}}/Chromium.app/Contents/Info.plist"]
    run "/usr/bin/plutil",
        args: ["-replace", "LSEnvironment.GOOGLE_DEFAULT_CLIENT_SECRET", "-string",
               "kdloedMFGdGla2P1zacGjAQh", "{{appdir}}/Chromium.app/Contents/Info.plist"]

    move "Chromium.app/Contents/MacOS/Chromium", "Chromium.app/Contents/MacOS/Chromium.real",
         source_base: :appdir, target_base: :appdir
    # Finder/Dock launches need a native executable, not a shell script.
    write_file "chromium-launcher.c", <<~EOS
      #include <stdio.h>
      #include <stdlib.h>
      #include <unistd.h>

      int main(int argc, char *argv[]) {
        const char *real_executable = "{{appdir}}/Chromium.app/Contents/MacOS/Chromium.real";
        const char *extra_args[] = {
          "--no-first-run",
          "--no-default-browser-check",
          "--allow-insecure-localhost",
          "--use-mock-keychain",
          "--disable-features=OSCryptAsyncAvailabilityInfoBar,OnDeviceModelBackgroundDownload,OptimizationGuideOnDeviceModel,AIPromptAPI,AIPromptAPIForWorkers,AIPromptAPILegacyIdentifiers,AIPromptAPILegacyParams,AIPromptAPIMultimodalInput,AIPromptAPIParams,AIPromptAPIStructuredOutput,AIPromptAPIToolUse,PromptApi",
        };
        const int extra_argc = sizeof(extra_args) / sizeof(extra_args[0]);
        char **exec_argv = calloc((size_t)argc + extra_argc + 1, sizeof(char *));
        if (!exec_argv) {
          perror("calloc");
          return 1;
        }

        exec_argv[0] = (char *)real_executable;
        for (int i = 0; i < extra_argc; i++) {
          exec_argv[i + 1] = (char *)extra_args[i];
        }
        for (int i = 1; i < argc; i++) {
          exec_argv[extra_argc + i] = argv[i];
        }

        execv(real_executable, exec_argv);
        perror("execv");
        return 1;
      }
    EOS
    run "/usr/bin/cc",
        args: ["{{staged_path}}/chromium-launcher.c", "-o", "{{appdir}}/Chromium.app/Contents/MacOS/Chromium"]
    set_permissions "Chromium.app/Contents/MacOS/Chromium", "0755", base: :appdir
    run "stage-custom-icon.sh", args: ["{{staged_path}}/custom-icon.icns"], base: :staged_path
    copy "custom-icon.icns", "Chromium.app/Contents/Resources/app.icns", target_base: :appdir
    # Use the custom ICNS instead of the upstream asset-catalog icon, then sign
    # the finished bundle. Finder custom-icon metadata invalidates strict signing.
    run "/usr/bin/plutil",
        args: ["-remove", "CFBundleIconName", "{{appdir}}/Chromium.app/Contents/Info.plist"]
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Chromium.app"]
    run "/usr/bin/codesign",
        args: ["--force", "--deep", "--sign", "-", "{{appdir}}/Chromium.app"]
  end

  zap trash: [
    "~/Library/Application Support/Chromium",
    "~/Library/Application Support/CrashReporter/Chromium_*.plist",
    "~/Library/Caches/Chromium",
    "~/Library/Logs/DiagnosticReports/Chromium-*.ips",
    "~/Library/Preferences/org.chromium.Chromium.plist",
    "~/Library/Saved Application State/org.chromium.Chromium.savedState",
  ]

  caveats <<~EOS
    This cask tracks the latest Chromium snapshot without a versioned livecheck.
    To refresh it manually, run:
      brew reinstall --cask zubb/tap/chromium
  EOS
end
