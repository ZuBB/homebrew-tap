cask "fishing-chrome" do
  arch arm: "arm64", intel: "x64"

  version "149.0.7827.22"
  sha256 :no_check

  url "https://storage.googleapis.com/chrome-for-testing-public/#{version}/mac-#{arch}/chrome-mac-#{arch}.zip",
      verified: "storage.googleapis.com/chrome-for-testing-public/"
  name "Fishing Chrome"
  desc "Official Chrome cooked for ..."
  homepage "https://googlechromelabs.github.io/chrome-for-testing/"

  livecheck do
    url "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
    strategy :page_match do |page|
      data = JSON.parse(page)
      data.dig("channels", "Stable", "version")
    end
  end

  auto_updates false
  depends_on macos: :big_sur

  app "chrome-mac-#{arch}/Google Chrome for Testing.app", target: "Fishing Chrome.app"

  postflight do
    app_path = "#{appdir}/Google Chrome for Testing.app"
    icon_path = "#{staged_path}/google-chrome-for-testing.icns"

    system_command '/opt/homebrew/bin/fileicon',
      args: ['set', '-q', app_path, icon_path]

#   system_command '/usr/bin/osascript',
#     args: [
#       '-e',
#       "use framework \"AppKit\"",
#       '-e',
#       "set appPath to \"#{app_path}\"",
#       '-e',
#       "set iconPath to \"#{icon_path}\"",
#       '-e',
#       "set image to current application's NSImage's alloc()'s initWithContentsOfFile:iconPath",
#       '-e',
#       "current application's NSWorkspace's sharedWorkspace()'s setIcon:image forFile:appPath options:0",
#     ]

    system_command '/usr/bin/xattr',
      args: ['-dr', 'com.apple.quarantine', app_path]

    system_command '/usr/bin/codesign',
      args: ['--force', '--deep', '--sign', '-', app_path]
  end
end

