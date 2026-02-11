# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::NamespaceSetting, feature_category: :ai_abstraction_layer do
  describe 'concerns' do
    it { is_expected.to include_module(Ai::HasRolePermissions) }

    it_behaves_like 'settings with role permissions'
  end

  describe 'database' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('namespace_ai_settings')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:ai_settings) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:duo_workflow_mcp_enabled).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:ai_usage_data_collection_enabled).in_array([true, false]) }
    it { is_expected.to validate_presence_of(:prompt_injection_protection_level) }
  end

  describe 'enums' do
    it 'defines prompt injection protection level enum' do
      is_expected.to define_enum_for(:prompt_injection_protection_level).with_values(log_only: 0, no_checks: 1,
        interrupt: 2)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:namespace_ai_settings)).to be_valid
    end
  end
end
