cask "google-chrome-testing" do
  arch arm: "arm64", intel: "x64"

  version "149.0.7779.0"
  sha256 :no_check

  url "https://storage.googleapis.com/chrome-for-testing-public/#{version}/mac-#{arch}/chrome-mac-#{arch}.zip",
      verified: "storage.googleapis.com/chrome-for-testing-public/"
  name "Google Chrome for Testing"
  desc "Official Chrome build for testing automation"
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

  preflight do
    cask_file_dir = Pathname.new(__FILE__).dirname
    icon_path = cask_file_dir/"../Resources/google-chrome-for-testing.icns"

    Dir.glob("#{staged_path}/chrome-mac-#{arch}/Google Chrome for Testing.app/**/Contents/Resources/app.icns").each do |target_icon_path|
      FileUtils.cp(icon_path, target_icon_path)
    end
  end

  postflight do
    system_command '/usr/bin/codesign',
      args: ['--force', '--deep', '--sign', '-', "#{appdir}/Fishing Chrome.app"]

    system_command '/usr/bin/xattr',
      args: ['-dr', 'com.apple.quarantine', "#{appdir}/Fishing Chrome.app"]
  end
end
