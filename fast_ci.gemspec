# frozen_string_literal: true

require_relative "lib/fast_ci/version"

Gem::Specification.new do |spec|
  spec.name          = "fast_ci"
  spec.version       = FastCI::VERSION
  spec.authors       = ["Ale ∴"]
  spec.email         = ["ale@alexvko.com"]

  spec.summary       = "Ruby wrapper for creating FastCI integrations"
  spec.description   = "Ruby wrapper for creating FastCI integrations"
  spec.homepage      = "https://github.com/alexvko/fast_ci-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "async-websocket", "~> 0.19"
  spec.add_development_dependency "pry"
end
