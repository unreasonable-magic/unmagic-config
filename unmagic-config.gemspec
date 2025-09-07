# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "unmagic-config"
  spec.version = "0.1.0"
  spec.authors = ["Quackback"]
  spec.email = ["support@quackback.dev"]
  spec.summary = "Configuration management library with environment variable support"
  spec.description = "Provides a DSL for defining environment-based configuration with validation, interpolation, and type conversion"
  spec.homepage = "https://quackback.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  # Optional dependency
  spec.add_development_dependency "addressable", "~> 2.8"
end