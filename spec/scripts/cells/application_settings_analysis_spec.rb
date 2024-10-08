# frozen_string_literal: true

require 'fast_spec_helper'
require 'gitlab/rspec/all'
require_relative '../../../scripts/cells/application-settings-analysis'

RSpec.describe ApplicationSettingsAnalysis, feature_category: :tooling do
  subject(:analyzer) { described_class.new(stdout: StringIO.new) }

  describe '#attributes_from_codebase' do
    subject(:attributes_from_codebase) { analyzer.attributes_from_codebase }

    describe 'return value' do
      it 'returns an array of described_class::ApplicationSetting' do
        expect(attributes_from_codebase).to all(be_a(described_class::ApplicationSetting))
      end
    end

    describe 'non-encrypted attribute' do
      it 'returns non-encrypted attributes from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'default_branch_name' }

        expect(setting).to be_present
      end
    end

    describe 'DB type' do
      it 'stores the column type from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'snippet_size_limit' }

        expect(setting.db_type).to eq('bigint')
      end
    end

    describe 'API type' do
      it 'fetches the API type from doc/api/settings.md' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'snippet_size_limit' }

        expect(setting.api_type).to eq('integer')
      end
    end

    describe 'attr_encrypted columns' do
      it 'returns encrypted attribute columns from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'encrypted_external_auth_client_key' }
        encryption_iv_column = attributes_from_codebase
          .find { |attr| attr.column == 'encrypted_external_auth_client_key_iv' }

        expect(setting.attr).to eq('external_auth_client_key') # `encrypted_` prefix is removed
        expect(setting.encrypted).to eq(true)
        expect(encryption_iv_column).to be_nil # `*_iv` column aren't listed as it's an implementation detail
      end
    end

    describe 'TokenAuthenticatable columns' do
      it 'returns encrypted attribute columns from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'runners_registration_token_encrypted' }

        expect(setting.attr).to eq('runners_registration_token') # `_encrypted` suffix is removed
        expect(setting.encrypted).to eq(true)
      end
    end

    describe 'column `not null`' do
      it 'stores the column `not null` from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'snippet_size_limit' }

        expect(setting.not_null).to eq(true)
      end
    end

    describe 'column default' do
      it 'stores the column default from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'snippet_size_limit' }

        expect(setting.default).to eq('52428800')
      end
    end

    describe 'attributes different than default on GitLab.com' do
      it 'marks settings that have a different value than default set on GitLab.com' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'zoekt_settings' }

        expect(setting.gitlab_com_different_than_default).to eq(true)
      end
    end

    describe 'attribute description' do
      it 'fetches attribute description from doc/api/settings.md' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'commit_email_hostname' }

        expect(setting.description).to eq('Custom hostname (for private commit emails).')
      end
    end

    describe 'JiHu-specific columns' do
      it 'fetches JiHu-specific columns from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'content_validation_endpoint_url' }

        expect(setting.jihu).to eq(true)
      end
    end

    describe 'HTML caching column' do
      it 'does not return _html-suffixed columns from db/structure.sql' do
        setting = attributes_from_codebase.find { |attr| attr.column.end_with?('_html') }

        expect(setting).to be_nil
      end
    end

    describe 'definition file' do
      it 'returns true when an attribute has an existing definition file' do
        setting = attributes_from_codebase.find { |attr| attr.column == 'commit_email_hostname' }

        expect(setting.definition_file_exist?).to eq(true)
      end
    end
  end

  describe '.definition_files' do
    it 'returns all definition files' do
      expect(described_class.definition_files).to eq(
        Dir.glob(File.expand_path("../../../config/application_setting_columns/*.yml", __dir__))
      )
    end
  end
end
