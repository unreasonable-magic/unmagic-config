# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Unmagic::Config namespace functionality" do
  # Create a test config class
  let(:test_config_class) do
    Class.new(Unmagic::Config) do
      self.env_files = []
      self.strip_prefix = "TEST_"

      namespace :database do
        config "TEST_DATABASE_HOST", as: :host, default: "localhost"
        config "TEST_DATABASE_PORT", type: :integer, as: :port, default: 5432
        config "TEST_DATABASE_SSL", type: :boolean, as: :ssl_enabled, default: false
        config "TEST_DATABASE_URL", type: :url, as: :url, validate: { required: false }
      end

      namespace :cache do
        config "TEST_CACHE_PROVIDER", as: :provider, default: "redis"
        config "TEST_CACHE_TTL", type: :integer, as: :ttl, default: 3600
      end

      namespace :email do
        config "TEST_EMAIL_SMTP_PORT", type: :integer, as: :smtp_port, default: nil, validate: { required: false }
        config "TEST_EMAIL_SMTP_TLS", type: :boolean, as: :smtp_tls, default: false, validate: { required: false }
      end
    end
  end

  before do
    # Clear any existing environment variables
    ENV.delete("TEST_DATABASE_HOST")
    ENV.delete("TEST_DATABASE_PORT")
    ENV.delete("TEST_DATABASE_SSL")
    ENV.delete("TEST_DATABASE_URL")
    ENV.delete("TEST_CACHE_PROVIDER")
    ENV.delete("TEST_CACHE_TTL")
    ENV.delete("TEST_EMAIL_SMTP_PORT")
    ENV.delete("TEST_EMAIL_SMTP_TLS")

    # Force configuration to reload
    test_config_class.instance_variable_set(:@configuration_loaded, false)
    test_config_class.instance_variable_set(:@namespaces, {})
  end

  describe "namespace definition" do
    it "creates a namespace method on the config class" do
      expect(test_config_class).to respond_to(:database)
      expect(test_config_class).to respond_to(:cache)
    end

    it "returns a NamespaceConfig instance" do
      expect(test_config_class.database).to be_a(Unmagic::Config::NamespaceConfig)
      expect(test_config_class.cache).to be_a(Unmagic::Config::NamespaceConfig)
    end
  end

  describe "accessing namespace configurations" do
    it "provides access to string configs with defaults" do
      expect(test_config_class.database.host).to eq("localhost")
      expect(test_config_class.cache.provider).to eq("redis")
    end

    it "provides access to integer configs with defaults" do
      expect(test_config_class.database.port).to eq(5432)
      expect(test_config_class.cache.ttl).to eq(3600)
    end

    it "provides access to boolean configs with defaults" do
      expect(test_config_class.database.ssl_enabled).to eq(false)
    end

    it "returns nil for optional URL configs when not set" do
      expect(test_config_class.database.url).to be_nil
    end

    context "with environment variables set" do
      before do
        ENV["TEST_DATABASE_HOST"] = "db.example.com"
        ENV["TEST_DATABASE_PORT"] = "3306"
        ENV["TEST_DATABASE_SSL"] = "true"
        ENV["TEST_DATABASE_URL"] = "postgres://user:pass@localhost/mydb"
        ENV["TEST_CACHE_PROVIDER"] = "memcached"
        ENV["TEST_CACHE_TTL"] = "7200"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
      end

      it "reads string values from environment" do
        expect(test_config_class.database.host).to eq("db.example.com")
        expect(test_config_class.cache.provider).to eq("memcached")
      end

      it "reads and converts integer values from environment" do
        expect(test_config_class.database.port).to eq(3306)
        expect(test_config_class.cache.ttl).to eq(7200)
      end

      it "reads and converts boolean values from environment" do
        expect(test_config_class.database.ssl_enabled).to eq(true)
      end

      it "reads and parses URL values from environment" do
        url = test_config_class.database.url
        # Can be either URI or Addressable::URI depending on whether addressable gem is loaded
        expect(url).to respond_to(:scheme)
        expect(url).to respond_to(:host)
        expect(url).to respond_to(:path)
        expect(url.scheme).to eq("postgres")
        expect(url.host).to eq("localhost")
        expect(url.path).to eq("/mydb")
      end
    end
  end

  describe "namespace introspection" do
    it "can convert namespace to hash" do
      hash = test_config_class.database.to_h
      expect(hash).to include(
        host: "localhost",
        port: 5432,
        ssl_enabled: false,
        url: nil
      )
    end

    it "provides meaningful inspect output" do
      inspect = test_config_class.database.inspect
      expect(inspect).to include("NamespaceConfig:database")
      expect(inspect).to include("host")
      expect(inspect).to include("localhost")
    end
  end

  describe "hash-like access methods" do
    describe "#[]" do
      it "accesses config values with bracket notation" do
        expect(test_config_class.database[:host]).to eq("localhost")
        expect(test_config_class.database[:port]).to eq(5432)
        expect(test_config_class.database[:ssl_enabled]).to eq(false)
      end

      it "accepts string keys" do
        expect(test_config_class.database["host"]).to eq("localhost")
        expect(test_config_class.cache["provider"]).to eq("redis")
      end

      it "returns nil for non-existent keys" do
        expect(test_config_class.database[:missing]).to be_nil
        expect(test_config_class.database[:unknown]).to be_nil
      end
    end

    describe "#keys" do
      it "returns all configuration keys" do
        expect(test_config_class.database.keys).to eq([ :host, :port, :ssl_enabled, :url ])
        expect(test_config_class.cache.keys).to eq([ :provider, :ttl ])
      end
    end

    describe "#values" do
      it "returns all configuration values" do
        expect(test_config_class.database.values).to eq([ "localhost", 5432, false, nil ])
        expect(test_config_class.cache.values).to eq([ "redis", 3600 ])
      end
    end
  end

  describe "hash-like fetch method" do
    it "fetches existing config values" do
      expect(test_config_class.database.fetch(:host)).to eq("localhost")
      expect(test_config_class.database.fetch(:port)).to eq(5432)
      expect(test_config_class.database.fetch(:ssl_enabled)).to eq(false)
    end

    it "accepts string keys and converts to symbols" do
      expect(test_config_class.database.fetch("host")).to eq("localhost")
      expect(test_config_class.database.fetch("port")).to eq(5432)
    end

    it "returns default value when key not found" do
      expect(test_config_class.database.fetch(:missing, "default")).to eq("default")
      expect(test_config_class.database.fetch(:unknown, nil)).to be_nil
    end

    it "yields to block when key not found and no default given" do
      result = test_config_class.database.fetch(:missing) { |key| "Missing key: #{key}" }
      expect(result).to eq("Missing key: missing")
    end

    it "raises KeyError when key not found and no default or block" do
      expect {
        test_config_class.database.fetch(:missing)
      }.to raise_error(KeyError, /key not found: :missing/)
    end

    context "with environment variables set" do
      before do
        ENV["TEST_DATABASE_HOST"] = "production.db.com"
        ENV["TEST_CACHE_TTL"] = "9999"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
        test_config_class.instance_variable_set(:@namespaces, {})
      end

      it "fetches values from environment" do
        expect(test_config_class.database.fetch(:host)).to eq("production.db.com")
        expect(test_config_class.cache.fetch(:ttl)).to eq(9999)
      end
    end
  end

  describe "TestConfig active_storage_primary namespace" do
    it "provides access to active storage configuration" do
      expect(TestConfig).to respond_to(:active_storage_primary)

      # The namespace should exist even if configs aren't set
      namespace = TestConfig.active_storage_primary
      expect(namespace).to be_a(Unmagic::Config::NamespaceConfig)

      # Should have the expected methods
      expect(namespace).to respond_to(:service)
      expect(namespace).to respond_to(:bucket)
      expect(namespace).to respond_to(:region)
      expect(namespace).to respond_to(:access_key_id)
      expect(namespace).to respond_to(:secret_access_key)
      expect(namespace).to respond_to(:endpoint)
      expect(namespace).to respond_to(:force_path_style)
    end

    context "with active storage environment variables" do
      before do
        ENV["TEST_ACTIVE_STORAGE_PRIMARY_SERVICE"] = "s3"
        ENV["TEST_ACTIVE_STORAGE_PRIMARY_BUCKET"] = "my-bucket"
        ENV["TEST_ACTIVE_STORAGE_PRIMARY_REGION"] = "us-east-1"
        ENV["TEST_ACTIVE_STORAGE_PRIMARY_FORCE_PATH_STYLE"] = "true"

        # Force configuration to reload
        TestConfig.instance_variable_set(:@configuration_loaded, false)
        TestConfig.instance_variable_set(:@namespaces, {})
      end

      after do
        ENV.delete("TEST_ACTIVE_STORAGE_PRIMARY_SERVICE")
        ENV.delete("TEST_ACTIVE_STORAGE_PRIMARY_BUCKET")
        ENV.delete("TEST_ACTIVE_STORAGE_PRIMARY_REGION")
        ENV.delete("TEST_ACTIVE_STORAGE_PRIMARY_FORCE_PATH_STYLE")

        # Force configuration to reload
        TestConfig.instance_variable_set(:@configuration_loaded, false)
        TestConfig.instance_variable_set(:@namespaces, {})
      end

      it "reads active storage configuration from environment" do
        namespace = TestConfig.active_storage_primary
        expect(namespace.service).to eq("s3")
        expect(namespace.bucket).to eq("my-bucket")
        expect(namespace.region).to eq("us-east-1")
        expect(namespace.force_path_style).to eq(true)
      end
    end

    it "maintains backward compatibility with legacy object access" do
      expect(TestConfig).to respond_to(:active_storage_primary_legacy)
    end
  end

  describe "optional integer and boolean types" do
    it "allows optional integers with default: nil and validate: { required: false }" do
      # Should not raise error when not set
      expect { test_config_class.email.smtp_port }.not_to raise_error
      expect(test_config_class.email.smtp_port).to be_nil
    end

    it "allows optional booleans with validate: { required: false }" do
      # Should not raise error when not set
      expect { test_config_class.email.smtp_tls }.not_to raise_error
      expect(test_config_class.email.smtp_tls).to eq(false)
    end

    context "with environment variables set" do
      before do
        ENV["TEST_EMAIL_SMTP_PORT"] = "587"
        ENV["TEST_EMAIL_SMTP_TLS"] = "true"

        # Force configuration to reload
        test_config_class.instance_variable_set(:@configuration_loaded, false)
      end

      it "reads integer values from environment" do
        expect(test_config_class.email.smtp_port).to eq(587)
      end

      it "reads boolean values from environment" do
        expect(test_config_class.email.smtp_tls).to eq(true)
      end
    end
  end
end
