# frozen_string_literal: true

require_relative "parser"

# Load .env files and validate for duplicate keys. This loader reads environment
# files and checks for duplicate key definitions across multiple files, which
# helps catch configuration errors early.
#
# Example:
#
#   loader = Unmagic::Config::EnvFile::Loader.new
#
#   # Load a single file
#   env_vars = loader.load(".env")
#
#   # Load multiple files with duplicate checking
#   env_vars = loader.load_multiple([".env", ".env.local"])
#
module Unmagic
  class Config
    module EnvFile
      class Loader
      class DuplicateKeysError < StandardError
        attr_reader :duplicates

        def initialize(duplicates)
          @duplicates = duplicates
        end

        def message
          list = @duplicates.map do |d|
            "- #{d[:key]} #{d[:path]}:#{d[:duplicate_line]} (first defined on line #{d[:first_line]})"
          end
          "#{@duplicates.length} duplicates detected in env files\n#{list.join("\n")}"
        end
      end

      def initialize
        @parser = Parser.new
      end

      # Load a single env file
      def load(path)
        return {} unless File.exist?(path)

        content = File.read(path)
        @parser.parse(content)
      end

      # Load multiple env files and check for duplicates
      def load_multiple(paths)
        env_vars = {}
        duplicates = []

        paths.each do |path|
          next unless File.exist?(path)

          # Check for duplicates
          duplicates.concat(search_for_duplicate_keys(path))

          # Parse the env file
          parsed_vars = load(path)
          env_vars.merge!(parsed_vars)
        end

        if duplicates.any?
          raise DuplicateKeysError.new(duplicates)
        end

        env_vars
      end

      private

      def search_for_duplicate_keys(path)
        first_seen = {}
        duplicates = []

        File.foreach(path).with_index(1) do |line, lineno|
          # Ignore empty lines and comments
          s = line.strip
          next if s.empty? || s.start_with?("#")

          # Grab KEY before the first '=' (supports `export KEY=...`)
          if line =~ /\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/
            key = Regexp.last_match(1)
            if first_seen.key?(key)
              duplicates << {
                path: path,
                key: key,
                first_line: first_seen[key],
                duplicate_line: lineno,
                content: line.chomp
              }
            else
              first_seen[key] = lineno
            end
          end
        end

        duplicates
      end
      end
    end
  end
end
