# frozen_string_literal: true

require "strscan"

# Handles environment variable interpolation in configuration values.
# Supports Docker Compose style variable expansion:
# - ${VAR} - Simple variable reference
# - ${VAR:-default} - Use default if VAR is unset or empty
# - ${VAR:?error} - Raise error if VAR is unset or empty
# - $VAR - Short form variable reference
#
# Example:
#
#   interpolator = Unmagic::Config::Interpolator.new(env: {"HOST" => "localhost"})
#   interpolator.interpolate("postgres://${HOST}:5432/db")
#   # => "postgres://localhost:5432/db"
#
#   interpolator.interpolate("${PORT:-3000}")
#   # => "3000"
#
module Unmagic
  class Config
    class Interpolator
    def initialize(env: {})
      @env = env
    end

    # Interpolate environment variables in a string
    # Supports: ${VAR}, ${VAR:-default}, ${VAR:?error}
    def interpolate(str)
      return str unless str.is_a?(String)

      str.gsub(/\$\{([^}]+)\}|\$([A-Za-z_][A-Za-z0-9_]*)/) do
        if Regexp.last_match(1)
          # ${...} form
          parse_variable_expansion(Regexp.last_match(1))
        else
          # $VAR form
          var_name = Regexp.last_match(2)
          # ENV takes precedence, then @env
          if @env
            ENV[var_name] || @env[var_name] || ""
          else
            ENV[var_name] || ""
          end
        end
      end
    end

    private

    # Parse variable expansion with modifiers
    # VAR, VAR:-default, VAR:?error
    def parse_variable_expansion(expr)
      scanner = StringScanner.new(expr)

      # Get the variable name
      var_name = scanner.scan(/[A-Za-z_][A-Za-z0-9_]*/)
      return "" unless var_name

      # ENV takes precedence, then @env
      value = if @env
        ENV[var_name] || @env[var_name]
      else
        ENV[var_name]
      end

      # Check for modifiers
      if scanner.scan(/:/)
        modifier = scanner.scan(/./)
        rest = scanner.rest

        case modifier
        when "-"
          # Use default if unset or empty
          value || rest
        when "?"
          # Error if unset or empty
          if value.nil? || value.empty?
            error_msg = rest.empty? ? "#{var_name}: parameter not set" : rest
            raise Unmagic::Config::MissingConfigError.new(error_msg)
          end
          value
        else
          # Unknown modifier, return as-is
          "${#{expr}}"
        end
      else
        # Simple variable reference
        value || ""
      end
    end
    end
  end
end
