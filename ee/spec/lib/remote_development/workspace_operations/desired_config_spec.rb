# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::DesiredConfig, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  subject(:desired_config) { described_class.new(desired_config_array: desired_config_array) }

  describe 'validations' do
    shared_examples 'invalid non-array config' do |value_description, test_value|
      context "when desired_config is #{value_description}" do
        let(:desired_config_array) { test_value }

        it 'fails' do
          expect(desired_config).to be_invalid
          expect(desired_config.errors[:desired_config_array]).to include("value at root is not an array")
        end
      end
    end

    include_examples 'invalid non-array config', 'a hash', {}
    include_examples 'invalid non-array config', 'nil', nil

    context 'when desired_config_array is empty' do
      let(:desired_config_array) { [] }

      it 'fails' do
        expect(desired_config).to be_invalid
        expect(desired_config.errors[:desired_config_array]).to include("can't be blank")
      end
    end

    context 'when desired_config is valid' do
      let(:desired_config_array) { create_desired_config_array }

      it 'passes' do
        expect(desired_config).to be_valid
      end
    end

    context 'when items in desired_config violate JSON schema' do
      let(:desired_config_array) do
        create_desired_config_array.map do |config|
          config.merge("invalid-field" => "value")
        end
      end

      it 'fails' do
        expect(desired_config).to be_invalid

        # This validation does not fail for other kinds except for ConfigMap
        # because they do not have "additionalProperties": false
        expect(desired_config.errors[:desired_config_array]).to include(
          "object property at `/0/invalid-field` is a disallowed additional property",
          "object property at `/6/invalid-field` is a disallowed additional property",
          "object property at `/7/invalid-field` is a disallowed additional property"
        )
      end
    end
  end

  describe '#to_json' do
    let(:desired_config_array) { create_desired_config_array }

    it { expect(desired_config.to_json).to be_valid_json }
  end
end
