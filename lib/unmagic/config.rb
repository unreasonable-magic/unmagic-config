# frozen_string_literal: true

require_relative "config/env_file/loader"
require_relative "config/interpolator"
require_relative "config/validators"
require_relative "config/dummy_values"
require_relative "config/namespace_config"

# Try to load addressable for better URL handling
begin
  require "addressable"
rescue LoadError
  # Optional dependency
end

module Unmagic
  # Main application configuration class that loads and manages environment-based
  # configuration. This class provides a DSL for defining configuration values
  # as class methods and handles loading from .env files, validation, interpolation,
  # and type conversion.
  #
  # Example:
  #
  #   class MyApp < Unmagic::Config
  #     config :database_url, env: "DATABASE_URL"
  #     config :port, as: :integer, env: "PORT", default: 3000
  #     config :ssl_enabled, as: :boolean, env: "SSL_ENABLED", default: false
  #     config :api_url, as: :url, env: "API_URL"
  #   end
  #
  #   MyApp.database_url  # => "postgres://localhost/myapp"
  #   MyApp.port          # => 3000
  #
  class Config
    class Error < StandardError; end
    class MissingConfigError < Error; end
    class BadConfigError < Error; end

    class << self
      attr_accessor :env_files, :strip_prefix

      # DSL method to define configuration values as class methods
      # Usage: config "ENV_VAR", type: :string, as: :method_name, default: value_or_lambda, scheme: :redis
      def config(env_var, type: :string, as: nil, default: nil, validate: {}, scheme: nil)
        # Auto-derive method name if not provided
        method_name = as || derive_method_name(env_var)

        # Store config metadata for later use (e.g., dummy value generation)
        @config_metadata ||= {}
        @config_metadata[env_var] = { type: type, scheme: scheme }

        # Define the class method
        define_singleton_method(method_name) do
          # Load configuration on first access if needed
          load_configuration! unless @configuration_loaded

          case type
          when :string
            fetch_string(env_var, default: default, validate: validate)
          when :integer
            parse_integer(env_var, default: default)
          when :boolean
            parse_boolean(env_var, default: default)
          when :url
            parse_url(env_var, default: default, scheme: scheme)
          when :ip_list
            parse_ip_list(env_var, default: default)
          when :object
            fetch_object(env_var)
          else
            raise Error.new("Unknown config type: #{type}")
          end
        end
      end

      # DSL method to define a namespace for grouped configurations
      # Usage:
      #   namespace :database do
      #     config "DATABASE_HOST", as: :host
      #     config "DATABASE_PORT", type: :integer, as: :port
      #   end
      def namespace(namespace_name, &block)
        # Initialize storage
        @namespaces ||= {}
        @namespace_blocks ||= {}

        # Store the block for later re-evaluation if needed
        @namespace_blocks[namespace_name] = block if block_given?

        # Create and configure the namespace immediately
        namespace_config = NamespaceConfig.new(self, namespace_name)
        namespace_config.instance_eval(&block) if block_given?
        @namespaces[namespace_name] = namespace_config

        # Define a class method that returns the namespace instance
        define_singleton_method(namespace_name) do
          # Initialize storage if not done
          @namespaces ||= {}
          @namespace_blocks ||= {}

          # Return existing namespace or create it if needed
          @namespaces[namespace_name] ||= begin
            ns = NamespaceConfig.new(self, namespace_name)
            # Re-evaluate the block if we have it stored
            stored_block = @namespace_blocks[namespace_name]
            ns.instance_eval(&stored_block) if stored_block
            ns
          end
        end
      end

      # Hash-like access with [] operator
      def [](key)
        key = key.to_sym
        if respond_to?(key)
          send(key)
        else
          nil
        end
      end

      # Hash-like fetch method with default and block support
      def fetch(key, *args)
        key = key.to_sym

        if respond_to?(key)
          send(key)
        elsif args.length > 0
          args.first
        elsif block_given?
          yield(key)
        else
          raise KeyError.new("key not found: #{key.inspect}")
        end
      end

      # Returns all configuration keys (method names)
      def keys
        # Get all singleton methods defined on this class, excluding Unmagic::Config methods
        config_methods = singleton_methods(false) - [ :env_files, :env_files=, :strip_prefix, :strip_prefix=,
                                                       :load_configuration!, :rails_env, :rails_root,
                                                       :[], :fetch, :keys, :values, :to_h ]
        config_methods.sort
      end

      # Returns all configuration values
      def values
        keys.map { |key| send(key) rescue nil }
      end

      # Convert all configs to a hash
      def to_h
        keys.each_with_object({}) do |key, hash|
          hash[key] = send(key) rescue nil
        end
      end

      def to_hash = to_h

      # Derive method name from environment variable name
      # APP_SECRET_KEY_BASE -> secret_key_base (when strip_prefix = "APP_")
      # SECRET_KEY_BASE -> secret_key_base
      def derive_method_name(env_var)
        name = env_var
        # Strip the configured prefix if present
        name = name.sub(/^#{Regexp.escape(strip_prefix)}/, "") if strip_prefix
        # Remove any wildcard suffix
        name = name.sub(/\*$/, "")
        # Convert to lowercase snake_case
        name.downcase.to_sym
      end

      # Load environment files and initialize configuration
      def load_configuration!(files: env_files || [ ".env" ], apply_to_env: false)
        return if @configuration_loaded

        # Check if we should use dummy values automatically (useful for asset precompilation)
        @use_dummy_values = ENV["UNMAGIC_CONFIG_USE_DUMMY_VALUES"] == "true"

        # Initialize components
        @env = {}
        @interpolator = Interpolator.new(env: @env)
        @validators = Validators.new
        @dummy_values = DummyValues.new(rails_root: rails_root)

        # Load env files
        env_files_list = Array(files)

        # Use the loader to load and validate env files
        loader = EnvFile::Loader.new
        parsed_vars = loader.load_multiple(env_files_list)

        # Check to see if the key exists in the real ENV, and preference that
        # over what's in the env file
        parsed_vars.each do |key, value|
          value = ENV.has_key?(key) ? ENV[key] : value

          # Only add to the env if we've been told to
          ENV[key] = value if apply_to_env

          @env[key] = value
        end

        @configuration_loaded = true
      end

      # Helper to get Rails environment without depending on Rails
      def rails_env
        @rails_env ||= ENV["RAILS_ENV"] || "development"
      end

      # Helper to get Rails root without depending on Rails
      def rails_root
        @rails_root ||= ENV["RAILS_ROOT"] || Dir.pwd
      end

      private

      # Fetch a string value with optional default and validation
      def fetch_string(key, default: nil, validate: {}, scheme: nil)
        # Check ENV first (takes precedence), then @env
        raw_value = ENV.has_key?(key) ? ENV[key] : @env[key]

        # Apply interpolation if value exists and is a string
        value = @interpolator.interpolate(raw_value)

        # Fall back to default - evaluate lambda if provided
        if value.nil? || value == ""
          value = if default.is_a?(Proc)
            # Execute lambda in the class context - use instance_exec to avoid arity issues
            instance_exec(&default)
          else
            default
          end
        end

        # Check if required (default is true unless explicitly set to false)
        required = validate.fetch(:required, true)
        using_dummy = false

        if required && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
          # Check for individual dummy flag or global dummy mode
          dummy_env = ENV["#{key}_DUMMY"]
          if @use_dummy_values || dummy_env == "1" || dummy_env&.downcase == "true"
            # Pass scheme to the dummy value generator for smarter URL generation
            value = @dummy_values.fetch_or_generate(key, scheme: scheme)
            using_dummy = true
          else
            raise MissingConfigError.new("#{key} is required but not set")
          end
        end

        # Validate the string value (skip validation if using dummy value)
        if !using_dummy
          @validators.validate_string(value, key: key, validate: validate)
        end

        # Return the value as-is or empty string if nil and not required
        value || ""
      end

      # Parse and validate a URL with optional default, returns URI object
      def parse_url(key, default: nil, validate: {}, scheme: nil)
        # Merge validation options, defaulting required to whether default is nil
        validate_opts = { required: default.nil? }.merge(validate)

        # Use fetch_string to handle all the ENV/validation/interpolation logic
        # Pass scheme for dummy value generation
        value = fetch_string(key, default: default, validate: validate_opts, scheme: scheme)

        return nil if value.nil? || value == ""

        # If block returned a URI, use it directly
        if value.is_a?(URI)
          value
        else
          # Otherwise parse the string
          @validators.parse_url(value.to_s, key: key)
        end
      end

      # Parse a comma-separated list of IP addresses/CIDR ranges
      def parse_ip_list(key, default: nil)
        ips_string = fetch_string(key, default: default, validate: { required: default.nil? })
        @validators.parse_ip_list(ips_string, key: key)
      end

      # Parse an integer with optional default
      def parse_integer(key, default: nil)
        value = fetch_string(key, default: default&.to_s, validate: { required: default.nil? })

        return default if value.empty? && !default.nil?

        @validators.parse_integer(value, key: key) || default
      end

      # Parse a boolean value with optional default
      def parse_boolean(key, default: nil)
        value = fetch_string(key, default: default&.to_s, validate: { required: default.nil? })

        return default if value.empty?

        result = @validators.parse_boolean(value, key: key)
        result.nil? ? default : result
      end

      # Fetch all environment variables with a given prefix and return as a hash
      def fetch_object(prefix_pattern)
        # Remove the asterisk if present and ensure it ends with underscore
        prefix = prefix_pattern.gsub(/\*$/, "")
        prefix += "_" unless prefix.end_with?("_")

        result = {}

        # Collect all keys from both ENV and @env
        all_keys = (@env.keys + ENV.keys).uniq

        all_keys.each do |key|
          if key.start_with?(prefix)
            # Extract the suffix after the prefix
            suffix = key[prefix.length..-1]

            # Convert to snake_case symbol (already lowercase from env var convention)
            symbol_key = suffix.downcase.to_sym

            # Use fetch_string to get the interpolated value
            result[symbol_key] = fetch_string(key, validate: { required: false })
          end
        end

        result
      end
    end

    # For backward compatibility, support instance usage
    def initialize(env_files: [ ".env" ], apply_to_env: false)
      self.class.env_files = env_files
      self.class.load_configuration!(files: env_files, apply_to_env: apply_to_env)
    end
  end
end
