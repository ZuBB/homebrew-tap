cask "google-chrome-testing" do
  arch arm: "arm64", intel: "x64"

  version "153.0.8010.52"
  sha256 arm:   "6f67faa4b34dd551b53abb6fee24edeae470ab695b0b100ddc4885ff0be6724a",
         intel: "01130a136cb492ff32a7253b2b8db9577bd3f7543574e2d7ce1a83ed1cbed3fd"

  url "https://storage.googleapis.com/chrome-for-testing-public/#{version}/mac-#{arch}/chrome-mac-#{arch}.zip"
  name "Google Chrome for Testing"
  desc "Official Chrome build for testing automation"
  homepage "https://googlechromelabs.github.io/chrome-for-testing/"

  livecheck do
    # https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json
    url "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
    strategy :page_match do |page|
      data = JSON.parse(page)
      data.dig("channels", "Stable", "version")
    end
  end

  auto_updates false
  depends_on macos: :ventura

  app "chrome-mac-#{arch}/Google Chrome for Testing.app", target: "Google Chrome for Testing.app"
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

  postflight_steps do
    run "stage-custom-icon.sh", args: ["{{staged_path}}/custom-icon.icns"], base: :staged_path
    copy "custom-icon.icns", "Google Chrome for Testing.app/Contents/Resources/app.icns", target_base: :appdir
    # Use the custom ICNS instead of the upstream asset-catalog icon, then sign
    # the finished bundle. Finder custom-icon metadata invalidates strict signing.
    run "/usr/bin/plutil",
        args: ["-remove", "CFBundleIconName", "{{appdir}}/Google Chrome for Testing.app/Contents/Info.plist"]
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Google Chrome for Testing.app"]
    run "/usr/bin/codesign",
        args: ["--force", "--deep", "--sign", "-", "{{appdir}}/Google Chrome for Testing.app"]
  end
end
