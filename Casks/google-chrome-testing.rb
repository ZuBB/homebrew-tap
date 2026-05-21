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

  app "chrome-mac-#{arch}/Google Chrome for Testing.app", target: "Google Chrome for Testing.app"

  preflight do
    cask_file_dir = Pathname.new(__FILE__).dirname

    # FileUtils.cp(cask_file_dir/"../Resources/google-chrome-for-testing.icns",
                 # "#{staged_path}/chrome-mac-#{arch}/Google Chrome for Testing.app/Contents/Resources/app.icns")

    Dir.glob("#{appdir}/Google Chrome for Testing.app/**/Contents/Resources/app.icns").each do |icon_path|
      FileUtils.cp(cask_file_dir/"../Resources/google-chrome-for-testing.icns", icon_path)
    end
  end

  postflight do
    system_command '/usr/bin/codesign',
      args: ['--force', '--deep', '--sign', '-', "#{appdir}/Google Chrome for Testing.app"]

    system_command '/usr/bin/xattr',
      args: ['-dr', 'com.apple.quarantine', "#{appdir}/Google Chrome for Testing.app"]
  end

  # zap trash: [
  #       "~/Library/Application Support/Google/Chrome for Testing",
  #       "~/Library/Caches/com.google.ChromeTesting",
  #       "~/Library/Preferences/com.google.ChromeTesting.plist",
  #       "~/Library/Saved Application State/com.google.ChromeTesting.savedState",
  #     ],
  #     rmdir: [
  #       "~/Library/Application Support/Google/Chrome for Testing",
  #       "~/Library/Caches/Google",
  #       "~/Library/Google",
  #     ]
end
