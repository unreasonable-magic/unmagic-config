# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unmagic::Config::Validators do
  let(:validators) { described_class.new }

  describe "#parse_boolean" do
    it "parses true values" do
      expect(validators.parse_boolean("true", key: "TEST")).to eq(true)
      expect(validators.parse_boolean("1", key: "TEST")).to eq(true)
      expect(validators.parse_boolean("yes", key: "TEST")).to eq(true)
      expect(validators.parse_boolean("on", key: "TEST")).to eq(true)
      expect(validators.parse_boolean("TRUE", key: "TEST")).to eq(true)
    end

    it "parses false values" do
      expect(validators.parse_boolean("false", key: "TEST")).to eq(false)
      expect(validators.parse_boolean("0", key: "TEST")).to eq(false)
      expect(validators.parse_boolean("no", key: "TEST")).to eq(false)
      expect(validators.parse_boolean("off", key: "TEST")).to eq(false)
      expect(validators.parse_boolean("FALSE", key: "TEST")).to eq(false)
    end

    it "returns nil for blank values" do
      expect(validators.parse_boolean("", key: "TEST")).to be_nil
      expect(validators.parse_boolean("   ", key: "TEST")).to be_nil
      expect(validators.parse_boolean("\t", key: "TEST")).to be_nil
      expect(validators.parse_boolean(nil, key: "TEST")).to be_nil
    end

    it "raises error for invalid values" do
      expect {
        validators.parse_boolean("invalid", key: "TEST")
      }.to raise_error(Unmagic::Config::BadConfigError, "TEST must be true/false, got: invalid")
    end
  end

  describe "#parse_integer" do
    it "parses integer values" do
      expect(validators.parse_integer("42", key: "TEST")).to eq(42)
      expect(validators.parse_integer("0", key: "TEST")).to eq(0)
      expect(validators.parse_integer("-123", key: "TEST")).to eq(-123)
    end

    it "returns nil for blank values" do
      expect(validators.parse_integer("", key: "TEST")).to be_nil
      expect(validators.parse_integer("   ", key: "TEST")).to be_nil
      expect(validators.parse_integer("\t", key: "TEST")).to be_nil
      expect(validators.parse_integer(nil, key: "TEST")).to be_nil
    end

    it "raises error for invalid values" do
      expect {
        validators.parse_integer("not_a_number", key: "TEST")
      }.to raise_error(Unmagic::Config::BadConfigError, "TEST must be an integer, got: not_a_number")
    end
  end

  describe "#parse_url" do
    it "parses valid URLs" do
      uri = validators.parse_url("https://example.com", key: "TEST")
      expect(uri.to_s).to eq("https://example.com")
    end

    it "returns nil for blank values" do
      expect(validators.parse_url("", key: "TEST")).to be_nil
      expect(validators.parse_url(nil, key: "TEST")).to be_nil
    end

    it "raises error for URLs without scheme" do
      expect {
        validators.parse_url("example.com", key: "TEST")
      }.to raise_error(Unmagic::Config::BadConfigError, /TEST must have a scheme/)
    end
  end

  describe "#parse_ip_list" do
    it "parses valid IP addresses" do
      ips = validators.parse_ip_list("127.0.0.1,192.168.1.0/24", key: "TEST")
      expect(ips).to eq([ "127.0.0.1", "192.168.1.0/24" ])
    end

    it "returns empty array for blank values" do
      expect(validators.parse_ip_list("", key: "TEST")).to eq([])
      expect(validators.parse_ip_list(nil, key: "TEST")).to eq([])
    end

    it "raises error for invalid IP addresses" do
      expect {
        validators.parse_ip_list("invalid.ip", key: "TEST")
      }.to raise_error(Unmagic::Config::BadConfigError, /TEST contains invalid IP/)
    end
  end

  describe "#validate_string" do
    it "validates required strings" do
      expect(validators.validate_string("value", key: "TEST", validate: { required: true })).to eq("value")
    end

    it "raises error for missing required values" do
      expect {
        validators.validate_string("", key: "TEST", validate: { required: true })
      }.to raise_error(Unmagic::Config::BadConfigError, "TEST is required but not set")

      expect {
        validators.validate_string(nil, key: "TEST", validate: { required: true })
      }.to raise_error(Unmagic::Config::BadConfigError, "TEST is required but not set")
    end

    it "allows empty values when not required" do
      expect(validators.validate_string("", key: "TEST", validate: { required: false })).to eq("")
      expect(validators.validate_string(nil, key: "TEST", validate: { required: false })).to be_nil
    end

    it "validates format when provided" do
      expect {
        validators.validate_string("abc", key: "TEST", validate: { format: /^\d+$/ })
      }.to raise_error(Unmagic::Config::BadConfigError, /TEST does not match required format/)

      expect(validators.validate_string("123", key: "TEST", validate: { format: /^\d+$/ })).to eq("123")
    end
  end
end
