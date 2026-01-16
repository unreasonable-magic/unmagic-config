# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unmagic::Config::EnvFile::Parser do
  let(:parser) { described_class.new }

  describe "#parse" do
    it "parses basic key=value pairs" do
      content = <<~ENV
        FOO=bar
        BAZ=qux
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "qux"
      })
    end

    it "handles double quoted values" do
      content = <<~ENV
        FOO="bar"
        EMPTY=""
        WITH_SPACES="hello world"
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "EMPTY" => "",
        "WITH_SPACES" => "hello world"
      })
    end

    it "handles single quoted values" do
      content = <<~ENV
        FOO='bar'
        EMPTY=''
        WITH_SPACES='hello world'
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "EMPTY" => "",
        "WITH_SPACES" => "hello world"
      })
    end

    it "strips inline comments after quoted values" do
      content = <<~ENV
        FOO=""  # This is a comment
        BAR="value" # Another comment
        BAZ='single'   # Comment with spaces
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "",
        "BAR" => "value",
        "BAZ" => "single"
      })
    end

    it "strips inline comments after unquoted values" do
      content = <<~ENV
        FOO=bar # This is a comment
        BAZ=123   # Comment with spaces
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "123"
      })
    end

    it "preserves # inside quoted values" do
      content = <<~ENV
        FOO="value # not a comment"
        BAR='value # also not a comment'
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "value # not a comment",
        "BAR" => "value # also not a comment"
      })
    end

    it "handles escape sequences in double quoted values" do
      content = <<~ENV
        NEWLINE="line1\\nline2"
        TAB="col1\\tcol2"
        QUOTE="say \\"hello\\""
        BACKSLASH="path\\\\to\\\\file"
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "NEWLINE" => "line1\nline2",
        "TAB" => "col1\tcol2",
        "QUOTE" => 'say "hello"',
        "BACKSLASH" => "path\\to\\file"
      })
    end

    it "handles escaped quotes in single quoted values" do
      content = <<~ENV
        QUOTE='say \\'hello\\''
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "QUOTE" => "say 'hello'"
      })
    end

    it "preserves variable interpolation syntax" do
      content = <<~ENV
        VAR1="${OTHER_VAR}"
        VAR2="${VAR:-default}"
        VAR3="${VAR:?error message}"
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "VAR1" => "${OTHER_VAR}",
        "VAR2" => "${VAR:-default}",
        "VAR3" => "${VAR:?error message}"
      })
    end

    it "ignores comment lines" do
      content = <<~ENV
        # This is a comment
        FOO=bar
        # Another comment
        BAZ=qux
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "qux"
      })
    end

    it "ignores empty lines" do
      content = <<~ENV
        FOO=bar

        BAZ=qux


      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "qux"
      })
    end

    it "handles export prefix" do
      content = <<~ENV
        export FOO=bar
        export BAZ="qux"
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "qux"
      })
    end

    it "handles whitespace around equals sign" do
      content = <<~ENV
        FOO = bar
        BAZ= qux
        QUX =baz
      ENV

      result = parser.parse(content)
      expect(result).to eq({
        "FOO" => "bar",
        "BAZ" => "qux",
        "QUX" => "baz"
      })
    end
  end
end
