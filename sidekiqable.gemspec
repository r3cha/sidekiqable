# frozen_string_literal: true

require_relative "lib/sidekiqable/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiqable"
  spec.version = Sidekiqable::VERSION
  spec.authors = ["Sidekiqable Maintainers"]
  spec.email = ["opensource@sidekiqable.dev"]

  spec.summary = "Schedule class methods asynchronously with Sidekiq via a proxy pattern."
  spec.description = "Sidekiqable lets you enqueue class method invocations directly by chaining perform_async, perform_in, or perform_at without writing boilerplate workers."
  spec.homepage = "https://github.com/r3cha/sidekiqable"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/r3cha/sidekiqable/blob/main/CHANGELOG.md"

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

  spec.add_dependency "sidekiq", ">= 6.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
