# frozen_string_literal: true

# Parse .env file contents using Docker Compose syntax. This parser extracts
# key-value pairs from .env files but doesn't perform variable interpolation,
# which is handled later by the configuration system.
#
# Supports:
# - Basic KEY=value format
# - Comments with #
# - Quoted values (single and double)
# - Variable interpolation syntax preservation: ${VAR}, ${VAR:-default}, ${VAR:?error}
# - Optional export keyword
#
# Example:
#
#   parser = Unmagic::Config::EnvFile::Parser.new
#   env_vars = parser.parse(File.read(".env"))
#   # => {"DATABASE_URL" => "postgres://localhost/myapp", "REDIS_URL" => "${REDIS_HOST}:6379"}
#
module Unmagic
  class Config
    module EnvFile
      class Parser
      def parse(content)
        env_vars = {}

        content.each_line do |line|
          # Skip empty lines and comments
          line = line.strip
          next if line.empty? || line.start_with?("#")

          # Match KEY=value with optional export prefix
          if line =~ /\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/
            key = Regexp.last_match(1)
            raw_value = Regexp.last_match(2)

            # Store the raw value without interpolation for dynamic evaluation
            # Only handle quote removal, not variable interpolation
            value = remove_quotes(raw_value)
            env_vars[key] = value
          end
        end

        env_vars
      end

      private

      # Remove quotes from a value without interpolation
      # This preserves ${VAR} syntax for later interpolation
      def remove_quotes(raw_value)
        return "" if raw_value.nil? || raw_value.empty?

        # Handle quoted strings
        if raw_value.start_with?('"') && raw_value.end_with?('"')
          # Remove surrounding double quotes and handle escape sequences
          content = raw_value[1..-2]
          content.gsub(/\\(.)/) do |match|
            case Regexp.last_match(1)
            when "n" then "\n"
            when "t" then "\t"
            when "r" then "\r"
            when "\\" then "\\"
            when '"' then '"'
            else match
            end
          end
        elsif raw_value.start_with?("'") && raw_value.end_with?("'")
          # Remove surrounding single quotes, only handle escaped single quotes
          raw_value[1..-2].gsub(/\\'/, "'")
        else
          # Unquoted value - return as-is
          raw_value
        end
      end
      end
    end
  end
end
