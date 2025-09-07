# frozen_string_literal: true

module Unmagic
  class Config
    # A namespace configuration class that acts as a container for grouped configurations.
    # This allows organizing related configurations under a single namespace object.
    #
    # Example:
    #   namespace :active_storage_primary do
    #     config "APP_ACTIVE_STORAGE_PRIMARY_SERVICE", as: :service
    #     config "APP_ACTIVE_STORAGE_PRIMARY_BUCKET", as: :bucket
    #   end
    #
    #   MyApp::Config.active_storage_primary.service  # => "s3"
    #   MyApp::Config.active_storage_primary.bucket   # => "my-bucket"
    class NamespaceConfig
    def initialize(parent_config, namespace_name)
      @parent_config = parent_config
      @namespace_name = namespace_name
      @configs = {}
    end

    # DSL method to define configuration values within this namespace
    def config(env_var, type: :string, as: nil, default: nil, validate: {})
      # Auto-derive method name if not provided
      method_name = as || @parent_config.derive_method_name(env_var)

      # Store the config definition
      @configs[method_name] = {
        env_var: env_var,
        type: type,
        default: default,
        validate: validate
      }

      # Define the instance method on this namespace
      define_singleton_method(method_name) do
        # Ensure parent configuration is loaded
        @parent_config.load_configuration! unless @parent_config.instance_variable_get(:@configuration_loaded)

        # Fetch the value using parent's methods
        case type
        when :string
          @parent_config.send(:fetch_string, env_var, default: default, validate: validate)
        when :integer
          @parent_config.send(:parse_integer, env_var, default: default)
        when :boolean
          @parent_config.send(:parse_boolean, env_var, default: default)
        when :url
          @parent_config.send(:parse_url, env_var, default: default, validate: validate)
        when :ip_list
          @parent_config.send(:parse_ip_list, env_var, default: default)
        else
          raise Unmagic::Config::Error.new("Unknown config type: #{type}")
        end
      end
    end

    # Hash-like access with [] operator
    def [](key)
      key = key.to_sym
      if @configs.key?(key)
        send(key)
      else
        nil
      end
    end

    # Hash-like fetch method for compatibility
    def fetch(key, *args)
      key = key.to_sym

      if @configs.key?(key)
        send(key)
      elsif args.length > 0
        args.first
      elsif block_given?
        yield(key)
      else
        raise KeyError.new("key not found: #{key.inspect}")
      end
    end

    # Returns all configuration keys
    def keys
      @configs.keys.sort
    end

    # Returns all configuration values
    def values
      keys.map { |key| send(key) rescue nil }
    end

    # Allow checking if a config is defined
    def respond_to_missing?(method_name, include_private = false)
      @configs.key?(method_name) || super
    end

    # Convert to hash
    def to_h
      @configs.keys.each_with_object({}) do |key, hash|
        hash[key] = send(key) rescue nil
      end
    end

    def to_hash = to_h

    def inspect
      "#<#{self.class.name}:#{@namespace_name} #{to_h.inspect}>"
    end
    end
  end
end
