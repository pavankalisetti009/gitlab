# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  describe '.available?' do
    let_it_be(:user) { create(:user) }

    subject(:available?) { described_class.available?(user) }

    context 'when SaaS', :saas do
      let_it_be(:non_member_group) do
        create(:group, namespace_settings: build(:namespace_settings, experiment_features_enabled: true))
      end

      where(:flag_enabled, :namespace_experiment_setting_enabled) do
        false | false
        true  | false
        false | true
        true  | true
      end

      with_them do
        let!(:member_group) do
          create(:group, guests: user, namespace_settings: build(:namespace_settings,
            experiment_features_enabled: namespace_experiment_setting_enabled
          ))
        end

        let(:true_when_all_enabled) do
          flag_enabled && namespace_experiment_setting_enabled
        end

        before do
          stub_feature_flags(global_ai_catalog: flag_enabled)
        end

        it { is_expected.to eq(true_when_all_enabled) }
      end
    end

    context 'when not SaaS' do
      where(:flag_enabled, :instance_duo_features_enabled, :instance_experiment_setting_enabled) do
        false | false | false
        true  | false | false
        false | true  | false
        false | false | true
        true  | true  | false
        true  | true  | true
      end

      with_them do
        let(:true_when_all_enabled) do
          flag_enabled && instance_duo_features_enabled && instance_experiment_setting_enabled
        end

        before do
          stub_feature_flags(global_ai_catalog: flag_enabled)
          stub_application_setting(duo_features_enabled: instance_duo_features_enabled)
          stub_application_setting(instance_level_ai_beta_features_enabled: instance_experiment_setting_enabled)
        end

        it { is_expected.to eq(true_when_all_enabled) }
      end
    end
  end
end
