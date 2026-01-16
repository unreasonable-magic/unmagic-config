# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Unmagic::Config with inline comments" do
  let(:test_config_class) do
    Class.new(Unmagic::Config) do
      self.env_files = []
      self.strip_prefix = "TEST_"

      config "TEST_SMTP_TLS", type: :boolean, as: :smtp_tls, default: false
      config "TEST_PORT", type: :integer, as: :port, default: 3000
      config "TEST_API_KEY", as: :api_key, default: "default-key"
    end
  end

  let(:env_file) { Tempfile.new("test.env") }

  before do
    ENV.delete("TEST_SMTP_TLS")
    ENV.delete("TEST_PORT")
    ENV.delete("TEST_API_KEY")
  end

  after do
    env_file.close
    env_file.unlink
  end

  it "handles inline comments after empty quoted boolean values" do
    env_file.write(<<~ENV)
      TEST_SMTP_TLS=""  # Set to "true" for implicit TLS on port 465
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.smtp_tls).to eq(false)
  end

  it "handles inline comments after empty quoted integer values" do
    env_file.write(<<~ENV)
      TEST_PORT=""  # Port number for the server
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.port).to eq(3000)
  end

  it "handles inline comments after empty quoted string values" do
    env_file.write(<<~ENV)
      TEST_API_KEY=""  # Your API key here
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.api_key).to eq("default-key")
  end

  it "handles inline comments after non-empty quoted boolean values" do
    env_file.write(<<~ENV)
      TEST_SMTP_TLS="true"  # Enable TLS
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.smtp_tls).to eq(true)
  end

  it "handles inline comments after non-empty quoted integer values" do
    env_file.write(<<~ENV)
      TEST_PORT="8080"  # Custom port
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.port).to eq(8080)
  end

  it "handles inline comments after non-empty quoted string values" do
    env_file.write(<<~ENV)
      TEST_API_KEY="secret-key-123"  # Production API key
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.api_key).to eq("secret-key-123")
  end

  it "handles inline comments after unquoted values" do
    env_file.write(<<~ENV)
      TEST_SMTP_TLS=true # Enable TLS
      TEST_PORT=8080 # Custom port
      TEST_API_KEY=my-key # My API key
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.smtp_tls).to eq(true)
    expect(test_config_class.port).to eq(8080)
    expect(test_config_class.api_key).to eq("my-key")
  end

  it "preserves # inside quoted values as part of the value" do
    env_file.write(<<~ENV)
      TEST_API_KEY="key#with#hashes"  # This comment is stripped
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.api_key).to eq("key#with#hashes")
  end

  it "handles inline comments with special characters" do
    env_file.write(<<~ENV)
      TEST_API_KEY="my-key"  # Comment with "quotes" and special chars!@#
    ENV
    env_file.rewind

    test_config_class.env_files = [ env_file.path ]
    test_config_class.instance_variable_set(:@configuration_loaded, false)

    expect(test_config_class.api_key).to eq("my-key")
  end
end
