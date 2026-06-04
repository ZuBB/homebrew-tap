class NodeCaged < Formula
  desc "Node.js with V8 pointer compression enabled"
  homepage "https://github.com/platformatic/node-caged"
  url "https://github.com/ZuBB/node-caged-bin/releases/download/v26.3.0-caged/node-v26.3.0-darwin-arm64.tar.gz"
  sha256 "6dd25f453cf55538ef5768e63d8fccdc17dcb842a893c425650226a1d2117281"
  license "MIT"

  livecheck do
    url "https://github.com/ZuBB/node-caged-bin/releases"
    regex(/^v?(\d+(?:\.\d+)+)-caged$/i)
  end

  depends_on arch: :arm64
  depends_on :macos

  conflicts_with "node", because: "node-caged installs node, npm, and npx"

  def install
    prefix.install Dir["*"]
  end

  def post_install
    node_modules = HOMEBREW_PREFIX/"lib/node_modules"
    node_modules.mkpath

    rm_r node_modules/"npm" if (node_modules/"npm").exist?
    cp_r lib/"node_modules/npm", node_modules

    ln_sf node_modules/"npm/bin/npm-cli.js", bin/"npm"
    ln_sf node_modules/"npm/bin/npx-cli.js", bin/"npx"
    ln_sf bin/"npm", HOMEBREW_PREFIX/"bin/npm"
    ln_sf bin/"npx", HOMEBREW_PREFIX/"bin/npx"

    (node_modules/"npm/npmrc").atomic_write("prefix = #{HOMEBREW_PREFIX}\n")
  end

  test do
    assert_equal "v26.3.0", shell_output("#{bin}/node --version").strip
    assert_equal "darwin-arm64", shell_output("#{bin}/node -p \"process.platform + '-' + process.arch\"").strip

    pointer_config = shell_output("#{bin}/node -p \"[
      process.config.variables.v8_enable_pointer_compression,
      process.config.variables.v8_enable_31bit_smis_on_64bit_arch,
      process.config.variables.v8_enable_external_code_space
    ].join(',')\"").strip
    assert_equal "1,1,1", pointer_config

    heap_limit = shell_output("#{bin}/node -p \"require('v8').getHeapStatistics().heap_size_limit\"").to_i
    assert_operator heap_limit, :<=, 4 * 1024 * 1024 * 1024

    assert_match "npm", shell_output("#{bin}/npm --version")
  end
end
