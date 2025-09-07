# frozen_string_literal: true

require "uri"
require "ipaddr"

# Validation utilities for configuration values. Provides methods to validate
# and parse different types of configuration values like URLs, IP addresses,
# integers, and booleans.
#
# Example:
#
#   validator = Unmagic::Config::Validators.new
#
#   # Validate and parse a URL
#   uri = validator.parse_url("https://example.com", key: "API_URL")
#
#   # Parse IP addresses
#   ips = validator.parse_ip_list("127.0.0.1,192.168.1.0/24", key: "ALLOWED_IPS")
#
#   # Parse boolean
#   enabled = validator.parse_boolean("true", key: "FEATURE_ENABLED")
#
module Unmagic
  class Config
    class Validators
    def initialize
    end

    # Validate a string value against validation rules
    def validate_string(value, key:, validate: {})
      # Check if required (default is true unless explicitly set to false)
      required = validate.fetch(:required, true)
      if required && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
        raise Unmagic::Config::BadConfigError.new("#{key} is required but not set")
      end

      # Check format if provided and value is a string
      if value.is_a?(String) && validate[:format]
        unless value.match?(validate[:format])
          raise Unmagic::Config::BadConfigError.new("#{key} does not match required format: #{validate[:format].inspect}")
        end
      end

      value
    end

    # Parse and validate a URL, returns URI object or Addressable::URI if available
    def parse_url(value, key:)
      return nil if value.nil? || value == ""

      # If value is already a URI, use it directly
      return value if value.is_a?(URI)

      url_string = value.to_s

      begin
        uri = URI.parse(url_string)

        # Allow any valid URI scheme (http, https, postgres, redis, etc.)
        if uri.scheme.nil?
          raise Unmagic::Config::BadConfigError.new("#{key} must have a scheme (e.g., http://, postgres://), got: #{url_string}")
        end

        # Use Addressable if available for better URL handling
        if defined?(Addressable)
          Addressable::URI.parse(url_string)
        else
          uri
        end
      rescue URI::InvalidURIError => e
        raise Unmagic::Config::BadConfigError.new("#{key} is not a valid URL: #{url_string} (#{e.message})")
      end
    end

    # Parse a comma-separated list of IP addresses/CIDR ranges
    def parse_ip_list(value, key:)
      return [] if value.nil? || value.empty?

      ips = value.split(",").map(&:strip).reject(&:empty?)

      ips.each do |ip|
        begin
          IPAddr.new(ip)
        rescue IPAddr::InvalidAddressError
          raise Unmagic::Config::BadConfigError.new("#{key} contains invalid IP/CIDR: #{ip}")
        end
      end

      ips
    end

    # Parse an integer value
    def parse_integer(value, key:)
      return nil if value.nil? || value.empty?

      begin
        Integer(value)
      rescue ArgumentError
        raise Unmagic::Config::BadConfigError.new("#{key} must be an integer, got: #{value}")
      end
    end

    # Parse a boolean value
    def parse_boolean(value, key:)
      return nil if value.nil? || value.empty?

      case value.to_s.downcase
      when "true", "1", "yes", "on"
        true
      when "false", "0", "no", "off"
        false
      else
        raise Unmagic::Config::BadConfigError.new("#{key} must be true/false, got: #{value}")
      end
    end
    end
  end
end
