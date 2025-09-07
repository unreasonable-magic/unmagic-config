# frozen_string_literal: true

require 'unmagic/config'

# Test configuration class for testing the unmagic-config library
class TestConfig < Unmagic::Config
  self.env_files = []
  self.strip_prefix = "TEST_"

  config "TEST_SECRET_KEY_BASE", as: :secret_key_base, default: "test-secret"
  config "TEST_PORT", type: :integer, as: :port, default: 3000
  config "TEST_RAILS_MAX_THREADS", type: :integer, as: :rails_max_threads, default: 5
  config "TEST_DATABASE_URL", type: :url, as: :database_url, validate: { required: false }

  namespace :active_storage_primary do
    config "TEST_ACTIVE_STORAGE_PRIMARY_SERVICE", as: :service, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_BUCKET", as: :bucket, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_REGION", as: :region, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_ACCESS_KEY_ID", as: :access_key_id, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_SECRET_ACCESS_KEY", as: :secret_access_key, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_ENDPOINT", as: :endpoint, validate: { required: false }
    config "TEST_ACTIVE_STORAGE_PRIMARY_FORCE_PATH_STYLE", type: :boolean, as: :force_path_style, validate: { required: false }
  end

  config "TEST_ACTIVE_STORAGE_PRIMARY*", type: :object, as: :active_storage_primary_legacy
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
