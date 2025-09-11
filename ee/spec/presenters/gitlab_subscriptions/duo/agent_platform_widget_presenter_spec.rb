# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::AgentPlatformWidgetPresenter, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:instance_admin?) { false }
    let(:gitlab_duo_saas_only_enabled?) { false }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(instance_admin?)
      stub_saas_features(gitlab_duo_saas_only: gitlab_duo_saas_only_enabled?)
    end

    subject(:attributes) { described_class.new(user).attributes }

    context 'when user is admin and gitlab_duo_saas_only is disabled' do
      let(:instance_admin?) { true }

      it 'delegates to SelfManaged::AuthorizedAgentPlatformWidgetPresenter' do
        expected_attributes = { duoAgentWidgetProvide: {} }
        expected_presenter = instance_double(
          GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter, attributes: expected_attributes
        )

        expect(GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter)
          .to receive(:new).with(user).and_return(expected_presenter)

        expect(attributes).to eq(expected_attributes)
      end
    end

    context 'when user is not an admin and gitlab_duo_saas_only is disabled' do
      let(:instance_admin?) { false }

      it 'delegates to SelfManaged::AgentPlatformWidgetPresenter' do
        expected_attributes = { duoAgentWidgetProvide: {} }
        expected_presenter = instance_double(
          GitlabSubscriptions::Duo::SelfManaged::AgentPlatformWidgetPresenter, attributes: expected_attributes
        )

        expect(GitlabSubscriptions::Duo::SelfManaged::AgentPlatformWidgetPresenter)
          .to receive(:new).with(user).and_return(expected_presenter)

        expect(attributes).to eq(expected_attributes)
      end
    end

    context 'when gitlab_duo_saas_only feature is enabled' do
      let(:gitlab_duo_saas_only_enabled?) { true }

      context 'when user is admin' do
        let(:instance_admin?) { true }

        it 'returns empty hash even for admin users' do
          expect(GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter).not_to receive(:new)

          expect(attributes).to eq({})
        end
      end
    end
  end
end
