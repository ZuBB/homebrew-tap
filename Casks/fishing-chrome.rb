cask "fishing-chrome" do
  arch arm: "arm64", intel: "x64"

  version "153.0.8010.52"
  sha256 arm:   "6f67faa4b34dd551b53abb6fee24edeae470ab695b0b100ddc4885ff0be6724a",
         intel: "01130a136cb492ff32a7253b2b8db9577bd3f7543574e2d7ce1a83ed1cbed3fd"

  url "https://storage.googleapis.com/chrome-for-testing-public/#{version}/mac-#{arch}/chrome-mac-#{arch}.zip"
  name "Fishing Chrome"
  desc "Official Chrome wrapped for some fishing experiments of me"
  homepage "https://googlechromelabs.github.io/chrome-for-testing/"

  livecheck do
    url "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
    strategy :page_match do |page|
      data = JSON.parse(page)
      data.dig("channels", "Stable", "version")
    end
  end

  auto_updates false
  depends_on macos: :ventura

  app "Fishing Chrome.app"
  generated_script "Fishing Chrome.app/Contents/MacOS/launcher", content: <<~'SH'
    #!/bin/sh
    set -eu
    contents=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
    profile=${FISHING_CHROME_USER_DATA_DIR:-"$HOME/Library/Application Support/Fishing Chrome"}
    case "$profile" in
      /*) ;;
      *) echo "FISHING_CHROME_USER_DATA_DIR must be an absolute path" >&2; exit 1 ;;
    esac
    exec "$contents/Helpers/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" \
      --no-first-run --no-default-browser-check "--user-data-dir=$profile" "$@"
  SH
  # The installer script runs before the app artifact. Prepare its icon before
  # Finder can cache the installed bundle, without reading tap files at runtime.
  generated_script "prepare-icon.sh", content: <<~SH
    #!/bin/sh
    set -eu
    staged_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    /usr/bin/base64 -D > "$staged_dir/Fishing Chrome.app/Contents/Resources/fishing-chrome.icns" <<'ICON'
    #{[((cask.tap || Tap.fetch("zubb/tap")).path/"Resources/fishing-chrome.icns").binread].pack("m0")}
    ICON
  SH
  installer script: { executable: "prepare-icon.sh" }

  # Keep browser resources separate from the launcher's identity and icon.
  preflight_steps do
    mkdir_p "Fishing Chrome.app/Contents/Helpers"
    # The icon must exist before Homebrew moves/registers the app in Finder.
    mkdir_p "Fishing Chrome.app/Contents/Resources"
    move "chrome-mac-#{arch}/Google Chrome for Testing.app",
         "Fishing Chrome.app/Contents/Helpers/Google Chrome for Testing.app"
    write_file "Fishing Chrome.app/Contents/Info.plist", <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
        <key>CFBundleExecutable</key><string>launcher</string>
        <key>CFBundleIdentifier</key><string>com.zubb.fishing-chrome</string>
        <key>CFBundleName</key><string>Fishing Chrome</string>
        <key>CFBundleDisplayName</key><string>Fishing Chrome</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>CFBundleIconFile</key><string>fishing-chrome.icns</string>
        <key>CFBundleShortVersionString</key><string>#{version}</string>
        <key>CFBundleVersion</key><string>#{version}</string>
        <key>LSMinimumSystemVersion</key><string>13.0</string>
      </dict>
      </plist>
    PLIST
  end

  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Fishing Chrome.app"]
    # Chrome for Testing ships with linker-only signatures. Seal the complete
    # bundle after customisation; Finder icon metadata would invalidate it.
    run "/usr/bin/codesign", args: ["--force", "--deep", "--sign", "-", "{{appdir}}/Fishing Chrome.app"]
    run "/usr/bin/codesign", args: ["--verify", "--deep", "--strict", "{{appdir}}/Fishing Chrome.app"]
  end

  caveats <<~EOS
    Fishing Chrome uses ~/Library/Application Support/Fishing Chrome by default.
    Set FISHING_CHROME_USER_DATA_DIR to an absolute path, or pass --user-data-dir,
    when launching from a terminal to use another profile. Existing profiles are
    not moved or deleted. Quit the browser fully before switching profiles.

    Allow the browser's Safe Storage Keychain request to persist encrypted login
    cookies across restarts. Denying access prevents it from obtaining that key.
    The launcher skips first-run setup, but does not bypass Keychain access.
  EOS
end
