# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::FeatureAuthorizer, feature_category: :ai_abstraction_layer do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:feature_name) { :summarize_review }
  let(:instance) do
    described_class.new(
      container: group,
      feature_name: feature_name,
      user: user
    )
  end

  subject(:allowed?) { instance.allowed? }

  describe '#allowed?' do
    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
    end

    context 'when container has correct setting and license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
      end

      context 'when ai_global_switch is turned off' do
        before do
          stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature_name => { self_managed: false })
        end

        it 'returns false' do
          stub_feature_flags(ai_global_switch: false)

          expect(allowed?).to be false
        end
      end

      context 'when duo features are disabled on container' do
        it 'returns false' do
          group.namespace_settings.update!(duo_features_enabled: false)

          expect(allowed?).to be false
        end
      end
    end

    context 'when user is not allowed to use feature' do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container does not have correct license' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when container is not present' do
      let(:instance) do
        described_class.new(
          container: nil,
          feature_name: feature_name,
          user: user
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when user is not present' do
      let(:instance) do
        described_class.new(
          container: group,
          feature_name: feature_name,
          user: nil
        )
      end

      it 'returns false' do
        expect(allowed?).to be false
      end
    end

    context 'when using custom licensed feature values' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      context 'when custom licensed_feature is specified' do
        let(:instance) do
          described_class.new(
            container: group,
            feature_name: feature_name,
            user: user,
            licensed_feature: :custom_feature
          )
        end

        it 'uses the specified licensed_feature' do
          expect(user).to receive(:allowed_to_use?).with(feature_name,
            licensed_feature: :custom_feature).and_return(true)
          expect(allowed?).to be true
        end
      end
    end
  end

  describe '.can_access_duo_external_trigger?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be(:container) { create(:group) }

    subject(:can_access) do
      described_class.can_access_duo_external_trigger?(user: user, container: container)
    end

    where(:duo_features_enabled, :assigned_to_add_ons, :assigned_to_core, :expected) do
      true  | true  | false | true
      true  | false | true  | true
      true  | true  | true  | true
      true  | false | false | false
      false | true  | false | false
      false | false | true  | false
      false | true  | true  | false
      false | false | false | false
    end

    with_them do
      before do
        container.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        allow(user).to receive(:assigned_to_duo_add_ons?).with(container).and_return(assigned_to_add_ons)
        allow(user).to receive(:assigned_to_duo_core?).with(container).and_return(assigned_to_core)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with a project container' do
      let_it_be(:container) { create(:project) }

      where(:duo_features_enabled, :assigned_to_add_ons, :assigned_to_core, :expected) do
        true  | true  | false | true
        true  | false | true  | true
        false | true  | false | false
      end

      with_them do
        before do
          container.update!(duo_features_enabled: duo_features_enabled)
          allow(user).to receive(:assigned_to_duo_add_ons?).with(container).and_return(assigned_to_add_ons)
          allow(user).to receive(:assigned_to_duo_core?).with(container).and_return(assigned_to_core)
        end

        it { is_expected.to eq(expected) }
      end
    end
  end
end
