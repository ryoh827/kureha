require "test_helper"
require "kureha"
require "fileutils"
require "open3"
require "rbconfig"
require "timeout"
require "tmpdir"

class TestSafetyVerification < Minitest::Test
  FIXTURES_DIR = File.expand_path("fixtures/verification", __dir__)
  TIMEOUT_SECONDS = 5

  def setup
    @minifier = Kureha::Minifier.new
  end

  def test_fixture_scenarios_preserve_behavior
    fixture_entrypoints.each do |fixture_path|
      verify_fixture(fixture_path)
    end
  end

  private

  def fixture_entrypoints
    Dir.glob(File.join(FIXTURES_DIR, "**/*.rb")).sort.reject do |path|
      File.basename(path).start_with?("_")
    end
  end

  def verify_fixture(fixture_path)
    source = File.read(fixture_path)
    minified = @minifier.minify(source)

    parse_result = Prism.parse(minified)
    assert !parse_result.failure?, "minified code is not parseable for #{fixture_name(fixture_path)}\n#{snippet(minified)}"

    Dir.mktmpdir("kureha-verify") do |tmpdir|
      FileUtils.cp_r(FIXTURES_DIR, tmpdir)
      staged_root = File.join(tmpdir, "verification")
      relative = fixture_path.delete_prefix("#{FIXTURES_DIR}/")
      original_path = File.join(staged_root, relative)
      minified_path = original_path.sub(/\.rb\z/, ".min.rb")
      File.write(minified_path, minified)

      original_result = run_script(original_path)
      minified_result = run_script(minified_path)

      message = failure_message(
        fixture: fixture_name(fixture_path),
        source: source,
        minified: minified,
        original_result: original_result,
        minified_result: minified_result
      )

      assert_equal original_result[:stdout], minified_result[:stdout], message
      assert_equal original_result[:stderr], minified_result[:stderr], message
      assert_equal original_result[:exit_status], minified_result[:exit_status], message
    end
  end

  def run_script(path)
    stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
      Open3.capture3(RbConfig.ruby, File.basename(path), chdir: File.dirname(path))
    end
    {
      stdout: stdout,
      stderr: stderr,
      exit_status: status.exitstatus
    }
  rescue Timeout::Error
    flunk("fixture timed out after #{TIMEOUT_SECONDS}s: #{fixture_name(path)}")
  end

  def fixture_name(path)
    path.delete_prefix("#{FIXTURES_DIR}/")
  end

  def failure_message(fixture:, source:, minified:, original_result:, minified_result:)
    [
      "fixture behavior mismatch: #{fixture}",
      "original exit: #{original_result[:exit_status]}",
      "minified exit: #{minified_result[:exit_status]}",
      "original stdout: #{snippet(original_result[:stdout])}",
      "minified stdout: #{snippet(minified_result[:stdout])}",
      "original stderr: #{snippet(original_result[:stderr])}",
      "minified stderr: #{snippet(minified_result[:stderr])}",
      "source: #{snippet(source)}",
      "minified: #{snippet(minified)}"
    ].join("\n")
  end

  def snippet(text, limit = 240)
    value = text.to_s.dump
    return value if value.length <= limit

    "#{value[0, limit]}..."
  end
end
