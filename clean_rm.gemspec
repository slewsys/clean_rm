# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'clean_rm/version'

Gem::Specification.new do |spec|
  spec.name          = "clean_rm"
  spec.version       = CleanRm::VERSION
  spec.authors       = ["Andrew L. Moore"]
  spec.email         = ["SlewSys@gmail.com"]

  spec.summary       = %q{Library for managing filesystem trash.}
  spec.description   = %q{Library for managing filesystem trash. Previously "deleted" versions of a file can be restored in reverse order of deletion. Each restore iteration replaces the current file with an older version until there are no more, then the newest version is restored again.

Command-line utility `trash' is intended as a cross-platform, option-compatible alternative to the Unix `rm(1)' command.}
  spec.homepage      = "https://github.com/slewsys/clean_rm"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sys-filesystem", "~> 1.1"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec-expectations", "~> 3.6.0"
  spec.add_development_dependency "rspec", "~> 3.6.0"
end
