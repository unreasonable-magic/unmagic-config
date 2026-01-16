# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Unmagic::Config hash-like access methods" do
  # Create a test config class
  let(:test_config_class) do
    Class.new(Unmagic::Config) do
      self.env_files = []
      self.strip_prefix = "TEST_"

      config "TEST_API_URL", type: :url, as: :api_url, validate: { required: false }
      config "TEST_SECRET_KEY", as: :secret_key, default: "default-secret"
      config "TEST_MAX_CONNECTIONS", type: :integer, as: :max_connections, default: 10
      config "TEST_ENABLED", type: :boolean, as: :enabled, default: true
      config "TEST_ALLOWED_IPS", type: :ip_list, as: :allowed_ips, default: "127.0.0.1"
    end
  end

  before do
    # Clear any existing environment variables
    ENV.delete("TEST_API_URL")
    ENV.delete("TEST_SECRET_KEY")
    ENV.delete("TEST_MAX_CONNECTIONS")
    ENV.delete("TEST_ENABLED")
    ENV.delete("TEST_ALLOWED_IPS")

    # Force configuration to reload
    test_config_class.instance_variable_set(:@configuration_loaded, false)
  end

  describe "#[]" do
    it "accesses config values with bracket notation" do
      expect(test_config_class[:secret_key]).to eq("default-secret")
      expect(test_config_class[:max_connections]).to eq(10)
      expect(test_config_class[:enabled]).to eq(true)
      expect(test_config_class[:allowed_ips]).to eq([ "127.0.0.1" ])
    end

    it "accepts string keys and converts to symbols" do
      expect(test_config_class["secret_key"]).to eq("default-secret")
      expect(test_config_class["max_connections"]).to eq(10)
    end

    it "returns nil for non-existent keys" do
      expect(test_config_class[:missing]).to be_nil
      expect(test_config_class[:unknown]).to be_nil
    end

    context "with environment variables set" do
      before do
        ENV["TEST_SECRET_KEY"] = "production-secret"
        ENV["TEST_MAX_CONNECTIONS"] = "50"
        ENV["TEST_ENABLED"] = "false"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
      end

      it "returns values from environment" do
        expect(test_config_class[:secret_key]).to eq("production-secret")
        expect(test_config_class[:max_connections]).to eq(50)
        expect(test_config_class[:enabled]).to eq(false)
      end
    end
  end

  describe "#fetch" do
    it "fetches existing config values" do
      expect(test_config_class.fetch(:secret_key)).to eq("default-secret")
      expect(test_config_class.fetch(:max_connections)).to eq(10)
      expect(test_config_class.fetch(:enabled)).to eq(true)
    end

    it "accepts string keys" do
      expect(test_config_class.fetch("secret_key")).to eq("default-secret")
      expect(test_config_class.fetch("enabled")).to eq(true)
    end

    it "returns default value when key not found" do
      expect(test_config_class.fetch(:missing, "default")).to eq("default")
      expect(test_config_class.fetch(:unknown, nil)).to be_nil
    end

    it "yields to block when key not found and no default given" do
      result = test_config_class.fetch(:missing) { |key| "Missing key: #{key}" }
      expect(result).to eq("Missing key: missing")
    end

    it "raises KeyError when key not found and no default or block" do
      expect {
        test_config_class.fetch(:missing)
      }.to raise_error(KeyError, /key not found: :missing/)
    end
  end

  describe "#keys" do
    it "returns all configuration keys sorted alphabetically" do
      expect(test_config_class.keys).to eq([ :allowed_ips, :api_url, :enabled, :max_connections, :secret_key ])
    end

    it "excludes internal methods from keys" do
      keys = test_config_class.keys
      expect(keys).not_to include(:env_files)
      expect(keys).not_to include(:strip_prefix)
      expect(keys).not_to include(:load_configuration!)
      expect(keys).not_to include(:fetch)
      expect(keys).not_to include(:keys)
      expect(keys).not_to include(:values)
    end
  end

  describe "#values" do
    it "returns all configuration values in key order" do
      expect(test_config_class.values).to eq([
        [ "127.0.0.1" ],  # allowed_ips
        nil,            # api_url
        true,           # enabled
        10,             # max_connections
        "default-secret" # secret_key
      ])
    end

    context "with environment variables set" do
      before do
        ENV["TEST_API_URL"] = "https://api.example.com"
        ENV["TEST_SECRET_KEY"] = "prod-secret"
        ENV["TEST_MAX_CONNECTIONS"] = "100"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
      end

      it "returns values from environment" do
        values = test_config_class.values
        expect(values[1].to_s).to include("api.example.com") # api_url (URI object)
        expect(values[3]).to eq(100) # max_connections
        expect(values[4]).to eq("prod-secret") # secret_key
      end
    end
  end

  describe "#to_h" do
    it "converts all configs to a hash" do
      hash = test_config_class.to_h
      expect(hash).to eq({
        allowed_ips: [ "127.0.0.1" ],
        api_url: nil,
        enabled: true,
        max_connections: 10,
        secret_key: "default-secret"
      })
    end

    context "with environment variables set" do
      before do
        ENV["TEST_API_URL"] = "https://api.example.com"
        ENV["TEST_SECRET_KEY"] = "prod-secret"
        ENV["TEST_ALLOWED_IPS"] = "10.0.0.0/8,192.168.0.0/16"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
      end

      it "includes values from environment" do
        hash = test_config_class.to_h
        expect(hash[:secret_key]).to eq("prod-secret")
        expect(hash[:api_url].to_s).to include("api.example.com")
        expect(hash[:allowed_ips]).to eq([ "10.0.0.0/8", "192.168.0.0/16" ])
      end
    end
  end

  describe "#reload!" do
    it "resets configuration loaded state" do
      test_config_class.instance_variable_set(:@configuration_loaded, false)
      test_config_class.load_configuration!

      expect(test_config_class.instance_variable_get(:@configuration_loaded)).to eq(true)

      test_config_class.reload!

      expect(test_config_class.instance_variable_get(:@configuration_loaded)).to eq(true)
      expect(test_config_class.instance_variable_get(:@env)).not_to be_nil
      expect(test_config_class.instance_variable_get(:@interpolator)).not_to be_nil
    end

    it "clears namespace caches" do
      namespace_config_class = Class.new(Unmagic::Config) do
        self.env_files = []
        self.strip_prefix = "TEST_"

        namespace :email do
          config "TEST_EMAIL_FROM", as: :from, default: "default@example.com"
        end
      end

      namespace_config_class.instance_variable_set(:@configuration_loaded, false)

      # Access namespace to initialize it
      expect(namespace_config_class.email.from).to eq("default@example.com")
      expect(namespace_config_class.instance_variable_get(:@namespaces)).not_to be_nil

      # Reload should clear namespaces
      namespace_config_class.reload!

      # After reload, can still access namespace
      expect(namespace_config_class.email.from).to eq("default@example.com")
    end

    it "picks up ENV changes after reload" do
      test_config_class.instance_variable_set(:@configuration_loaded, false)

      # Initial load without ENV var
      ENV.delete("TEST_SECRET_KEY")
      expect(test_config_class.secret_key).to eq("default-secret")

      # Set ENV var and reload
      ENV["TEST_SECRET_KEY"] = "new-value"
      test_config_class.reload!

      expect(test_config_class.secret_key).to eq("new-value")

      # Clean up
      ENV.delete("TEST_SECRET_KEY")
    end
  end

  describe "real TestConfig" do
    it "supports bracket access" do
      expect(TestConfig).to respond_to(:[])
      expect(TestConfig).to respond_to(:fetch)
      expect(TestConfig).to respond_to(:keys)
      expect(TestConfig).to respond_to(:values)
      expect(TestConfig).to respond_to(:to_h)
    end

    it "can access configurations via brackets" do
      # These will use defaults or dummy values in test
      expect(TestConfig[:port]).to eq(3000)
      expect(TestConfig["port"]).to eq(3000)
      expect(TestConfig[:rails_max_threads]).to eq(5)
    end

    it "returns sorted keys" do
      keys = TestConfig.keys
      expect(keys).to be_a(Array)
      expect(keys).to eq(keys.sort)
      expect(keys).to include(:port)
      expect(keys).to include(:secret_key_base)
      expect(keys).to include(:active_storage_primary)
    end
  end
end
