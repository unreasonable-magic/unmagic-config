# frozen_string_literal: true

require "securerandom"
require "fileutils"

# Generates and manages dummy values for configuration in development/test
# environments. Dummy values are persisted in tmp/ directory to ensure
# consistency across processes and restarts.
#
# Example:
#
#   generator = Unmagic::Config::DummyValues.new(rails_root: Rails.root)
#
#   # Generate a dummy secret key
#   key = generator.fetch_or_generate("SECRET_KEY_BASE")
#   # => "dummy-abc123..." (same value on subsequent calls)
#
#   # Generate a dummy URL
#   url = generator.fetch_or_generate("API_URL")
#   # => "https://dummy.test"
#
module Unmagic
  class Config
    class DummyValues
    def initialize(rails_root: Dir.pwd)
      @rails_root = rails_root
    end

    # Generate or fetch a dummy value for a configuration key
    # Stores the value in tmp/dummy_<key>.txt for consistency across processes
    def fetch_or_generate(key, scheme: nil)
      # Determine the file path for storing the dummy value
      dummy_file_path = File.join(@rails_root, "tmp", "dummy_#{key.downcase}.txt")

      # If the file exists, return its contents
      if File.exist?(dummy_file_path)
        return File.read(dummy_file_path).strip
      end

      # Generate appropriate dummy value based on scheme or key patterns
      dummy_value = generate_dummy_value(key, scheme: scheme)

      # Ensure tmp directory exists
      FileUtils.mkdir_p(File.dirname(dummy_file_path))

      # Write the dummy value to file for persistence
      File.write(dummy_file_path, dummy_value)

      dummy_value
    end

    private

    def generate_dummy_value(key, scheme: nil)
      # If scheme is provided, use it to generate appropriate URL
      if scheme
        case scheme
        when :postgres, :postgresql
          return "postgresql://dummy:dummy@localhost:5432/dummy_db"
        when :redis
          return "redis://localhost:6379/0"
        when :mysql
          return "mysql://dummy:dummy@localhost:3306/dummy_db"
        when :https
          return "https://dummy.test"
        when :http
          return "http://dummy.test"
        end
      end

      # Fall back to pattern matching on the key name
      case key
      when /REDIS.*URL$/
        "redis://localhost:6379/0"
      when /DATABASE_URL$/
        "postgresql://dummy:dummy@localhost:5432/dummy_db"
      when /_URL$/
        "https://dummy.test"
      when /_EMAIL$/
        "dummy@example.com"
      when /_PATH$/
        "/tmp/dummy-path-#{SecureRandom.hex(8)}"
      when /_ROOT$/
        "/tmp/dummy-root-#{SecureRandom.hex(8)}"
      when /_KEY$/, /_SECRET$/
        "dummy-#{SecureRandom.hex(61)}"
      when /_TOKEN$/
        "dummy-token-#{SecureRandom.hex(32)}"
      when /_ID$/
        "dummy-id-#{SecureRandom.hex(16)}"
      else
        "dummy-#{SecureRandom.hex(61)}"
      end
    end
    end
  end
end
