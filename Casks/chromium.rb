cask "chromium" do
  arch arm: "Mac_Arm", intel: "Mac"

  version :latest
  sha256 :no_check

  url "https://download-chromium.appspot.com/dl/#{arch}?type=snapshots",
      verified: "download-chromium.appspot.com/dl/"
  name "Chromium"
  desc "Free and open-source web browser"
  homepage "https://www.chromium.org/Home"

  conflicts_with cask: "ungoogled-chromium"
  depends_on macos: :monterey

  app "chrome-mac/Chromium.app"

  shimscript = "#{staged_path}/chromium.wrapper.sh"
  binary shimscript, target: "chromium"

  preflight do
    File.write shimscript, <<~EOS
      #!/bin/sh
      exec '#{appdir}/Chromium.app/Contents/MacOS/Chromium' "$@"
    EOS
  end

  postflight do
    app_path = "#{appdir}/Chromium.app"
    executable = "#{app_path}/Contents/MacOS/Chromium"
    real_executable = "#{app_path}/Contents/MacOS/Chromium.real"
    cask_file_dir = Pathname.new(__FILE__).dirname
    icon_path = cask_file_dir/"../Resources/google-chrome-for-testing.icns"
    plist = "#{app_path}/Contents/Info.plist"

    google_api_keys = {
      "LSEnvironment.GOOGLE_API_KEY"               => "AIzaSyCkfPOPZXDKNn8hhgu3JrA62wIgC93d44k",
      "LSEnvironment.GOOGLE_DEFAULT_CLIENT_ID"     => "811574891467.apps.googleusercontent.com",
      "LSEnvironment.GOOGLE_DEFAULT_CLIENT_SECRET" => "kdloedMFGdGla2P1zacGjAQh",
    }

    google_api_keys.each do |key, value|
      system_command '/usr/bin/plutil',
        args: ['-replace', key, '-string', value, plist]
    end

    File.rename executable, real_executable
    # LaunchServices rejects a shell script as CFBundleExecutable on some macOS
    # versions, so use a tiny native launcher to inject Finder/Dock launch flags.
    launcher_source = "#{staged_path}/chromium-launcher.c"
    File.write launcher_source, <<~EOS
      #include <stdio.h>
      #include <stdlib.h>
      #include <unistd.h>

      int main(int argc, char *argv[]) {
        const char *real_executable = "#{real_executable}";
        const char *extra_args[] = {
          "--no-first-run",
          "--no-default-browser-check",
          "--allow-insecure-localhost",
          "--use-mock-keychain",
          "--disable-features=OSCryptAsyncAvailabilityInfoBar",
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
    system_command '/usr/bin/cc',
      args: [launcher_source, '-o', executable]
    File.chmod 0755, executable

    system_command '/usr/bin/xattr',
      args: ['-dr', 'com.apple.quarantine', app_path]

    system_command '/usr/bin/codesign',
      args: ['--force', '--deep', '--sign', '-', app_path]

    system_command '/usr/bin/osascript',
      args: [
        '-e',
        "use framework \"AppKit\"",
        '-e',
        "set appPath to \"#{app_path}\"",
        '-e',
        "set iconPath to \"#{icon_path}\"",
        '-e',
        "set image to current application's NSImage's alloc()'s initWithContentsOfFile:iconPath",
        '-e',
        "current application's NSWorkspace's sharedWorkspace()'s setIcon:image forFile:appPath options:0",
      ]
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
