# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::NamespaceFeatureSetting, feature_category: :"self-hosted_models" do
  let(:group) { create(:group) }
  let(:ff_enabled) { true }

  subject(:ai_feature_setting) do
    build(:ai_namespace_feature_setting, namespace: group)
  end

  before do
    stub_feature_flags(ai_model_switching: ff_enabled)
  end

  describe 'associations' do
    it 'belongs to groups' do
      is_expected.to belong_to(:namespace)
         .class_name('::Group')
         .inverse_of(:ai_feature_settings)
    end

    it { is_expected.to validate_uniqueness_of(:feature).scoped_to(:namespace_id).ignoring_case_sensitivity }
  end

  describe '.find_or_initialize_by_feature' do
    let(:existing_feature) { ai_feature_setting.feature.to_sym }
    let(:new_feature_enum) { :code_completions }

    it 'returns existing setting when one exists for the feature' do
      ai_feature_setting.save!
      result = described_class.find_or_initialize_by_feature(group, existing_feature)

      expect(result).to eq(ai_feature_setting)
    end

    it 'initializes a new setting when none exists for the feature' do
      new_feature = :code_completions
      result = described_class.find_or_initialize_by_feature(group, new_feature_enum)

      expect(result).to be_a(described_class)
      expect(result).to be_new_record
      expect(result.namespace).to eq(group)
      expect(result.feature).to eq(new_feature.to_s)
    end

    context 'when the feature is not enabled' do
      let(:ff_enabled) { false }

      subject(:ai_feature_setting) { build(:ai_namespace_feature_setting) }

      it 'returns nil' do
        result = described_class.find_or_initialize_by_feature(group, existing_feature)
        expect(result).to be_nil
      end
    end
  end

  it_behaves_like 'model selection feature setting', scope_class_name: 'Group'

  describe 'validations' do
    include_context 'with model selection definitions'

    describe '#validate_root_namespace' do
      let(:parent_group) { create(:group) }
      let(:group) { create(:group, parent: parent_group) }

      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          namespace: group,
          feature: valid_feature)
      end

      it 'adds an error about top-level namespaces' do
        expect(ai_feature_setting.valid?).to be false

        expect(ai_feature_setting.errors[:namespace])
          .to include('Model selection is only available for top-level namespaces.')
      end
    end

    it_behaves_like '#validate_model_selection_enabled is called'

    describe '#validate_model_ref_with_definition' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          feature: valid_feature,
          offered_model_ref: model_ref,
          model_definitions: model_definitions)
      end

      it_behaves_like '#validate_model_ref_with_definition is called'
    end

    describe '#set_model_name' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          feature: valid_feature,
          offered_model_ref: model_ref,
          model_definitions: model_definitions)
      end

      it_behaves_like '#set_model_name is called'
    end
  end
end
