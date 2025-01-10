# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CustomRoles::Definition, feature_category: :permissions do
  yaml_files = Dir.glob(Rails.root.join("ee/config/custom_abilities/*.yml"))

  describe '.all' do
    subject(:abilities) { described_class.all }

    let_it_be(:defined_abilities) do
      yaml_files.map do |file|
        File.basename(file, '.yml').to_sym
      end
    end

    context 'when initialized' do
      it 'does not reload the abilities from the yaml files' do
        expect(described_class).not_to receive(:load_abilities!)

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(defined_abilities)
      end
    end

    context 'when not initialized' do
      before do
        described_class.instance_variable_set(:@definitions, nil)
      end

      it 'reloads the abilities from the yaml files' do
        expect(described_class).to receive(:load_abilities!)

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(defined_abilities)
      end
    end
  end

  describe 'validations' do
    def validate(data)
      validator.validate(data).pluck('error')
    end

    let_it_be(:validator) do
      JSONSchemer.schema(Pathname.new(Rails.root.join('ee/config/custom_abilities/type_schema.json')))
    end

    yaml_files.each do |ability_file|
      it "validates #{ability_file}" do
        data = YAML.load_file(ability_file)

        expect(validate(data)).to be_empty
      end
    end
  end
end
