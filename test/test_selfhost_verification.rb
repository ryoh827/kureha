require "test_helper"
require "kureha"
require "fileutils"
require "open3"
require "rbconfig"
require "timeout"
require "tmpdir"
require "prism"

class TestSelfhostVerification < Minitest::Test
  LIB_ROOT = File.expand_path("../lib", __dir__)
  TIMEOUT_SECONDS = 5
  SAMPLE_SOURCE = "x = 1 + 2\nputs x\n"
  EXPECTED_MINIFIED = "x=1+2;puts x"

  def setup
    @minifier = Kureha::Minifier.new
    @prism_lib = File.join(Gem::Specification.find_by_name("prism").full_gem_path, "lib")
  end

  def test_minified_lib_is_parseable_and_runnable
    files = Dir.glob(File.join(LIB_ROOT, "**/*.rb")).sort
    refute_empty files

    Dir.mktmpdir("kureha-selfhost") do |tmpdir|
      files.each do |path|
        minified = @minifier.minify(File.read(path))
        parse_result = Prism.parse(minified)
        assert !parse_result.failure?, parse_failure_message(path, parse_result, minified)

        relative = path.delete_prefix("#{LIB_ROOT}/")
        output_path = File.join(tmpdir, "lib", relative)
        FileUtils.mkdir_p(File.dirname(output_path))
        File.write(output_path, minified)
      end

      stdout, stderr, exit_status = run_minified_kureha(tmpdir)

      assert_equal 0, exit_status, "selfhost process exited with #{exit_status}\nstderr=#{snippet(stderr)}"
      assert_equal "", stderr, "selfhost process wrote to stderr: #{snippet(stderr)}"
      assert_equal EXPECTED_MINIFIED, stdout, "unexpected minify output from selfhosted kureha"
    end
  end

  private

  def run_minified_kureha(tmpdir)
    code = %(require "kureha"; print Kureha::Minifier.new.minify("x = 1 + 2\\nputs x\\n"))
    env = {
      "RUBYOPT" => nil,
      "RUBYLIB" => nil,
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLE_PATH" => nil,
      "BUNDLE_DISABLE_SHARED_GEMS" => nil
    }

    stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
      Open3.capture3(
        env,
        RbConfig.ruby,
        "-I",
        File.join(tmpdir, "lib"),
        "-I",
        @prism_lib,
        "-e",
        code,
        chdir: tmpdir
      )
    end

    [stdout, stderr, status.exitstatus]
  rescue Timeout::Error
    flunk("selfhost process timed out after #{TIMEOUT_SECONDS}s")
  end

  def parse_failure_message(path, parse_result, minified)
    messages = parse_result.errors.map(&:message).join(" | ")
    "selfhost parse failed for #{path}: #{messages}\n#{snippet(minified)}"
  end

  def snippet(text, limit = 240)
    value = text.to_s.dump
    return value if value.length <= limit

    "#{value[0, limit]}..."
  end
end
