# frozen_string_literal: true

require_relative "lib/kureha/version"

Gem::Specification.new do |spec|
  spec.name = "kureha"
  spec.version = RubyMinifier::VERSION
  spec.authors = ["ryoh827"]
  spec.email = ["ryoh827.dev@gmail.com"]

  spec.summary = "A Ruby minifier."
  spec.description = "A safe and lightweight Ruby code minifier using Prism AST, preserving syntax while removing unnecessary spaces."
  spec.homepage = "https://github.com/ryoh827/kureha"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ryoh827/kureha"
  spec.metadata["changelog_uri"] = "https://github.com/ryoh827/kureha/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "prism", ">= 0.24", "< 1.5"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
