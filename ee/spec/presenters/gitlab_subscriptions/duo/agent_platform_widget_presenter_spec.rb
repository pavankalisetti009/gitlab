# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::AgentPlatformWidgetPresenter, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:authorized?) { true }
    let(:gitlab_duo_saas_only_enabled?) { false }
    let(:context) { nil }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(authorized?)
      stub_saas_features(gitlab_duo_saas_only: gitlab_duo_saas_only_enabled?)
    end

    subject(:attributes) { described_class.new(user, context: context).attributes }

    context 'when gitlab_duo_saas_only is disabled' do
      it 'delegates to SelfManaged::AuthorizedAgentPlatformWidgetPresenter' do
        expected_attributes = { duoAgentWidgetProvide: {} }
        expected_presenter = instance_double(
          GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter, attributes: expected_attributes
        )

        expect(GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter)
          .to receive(:new).with(user).and_return(expected_presenter)

        expect(attributes).to eq(expected_attributes)
      end

      context 'when user is not an admin' do
        let(:authorized?) { false }

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
    end

    context 'when gitlab_duo_saas_only feature is enabled' do
      let(:gitlab_duo_saas_only_enabled?) { true }
      let(:context) { build_stubbed(:group) }
      let(:request_authorized?) { true }

      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, context).and_return(authorized?)
        allow(Ability)
          .to receive(:allowed?).with(user, :read_namespace_via_membership, context).and_return(request_authorized?)
      end

      context 'when user is an owner' do
        let(:context) { build_stubbed(:group) }

        context 'when context is a top-level group' do
          it 'delegates to GitlabCom::AuthorizedAgentPlatformWidgetPresenter' do
            expected_attributes = { duoAgentWidgetProvide: {} }
            expected_presenter = instance_double(
              GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter,
              attributes: expected_attributes
            )

            expect(GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter)
              .to receive(:new).with(user, context).and_return(expected_presenter)

            expect(attributes).to eq(expected_attributes)
          end
        end

        context 'when context is a project' do
          let(:context) { build_stubbed(:project) }

          it 'returns empty hash' do
            expect(GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter).not_to receive(:new)

            expect(attributes).to eq({})
          end
        end

        context 'when context is a sub-group' do
          let(:context) { build_stubbed(:group, :nested) }

          it 'returns empty hash' do
            expect(GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter).not_to receive(:new)

            expect(attributes).to eq({})
          end
        end
      end

      context 'when user is a non owner member' do
        let(:authorized?) { false }

        context 'when context is a top-level group' do
          it 'delegates to GitlabCom::AuthorizedAgentPlatformWidgetPresenter' do
            expected_attributes = { duoAgentWidgetProvide: {} }
            expected_presenter = instance_double(
              GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter,
              attributes: expected_attributes
            )

            expect(GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter)
              .to receive(:new).with(user, context).and_return(expected_presenter)

            expect(attributes).to eq(expected_attributes)
          end
        end

        context 'when context is a project' do
          let(:context) { build_stubbed(:project) }

          it 'returns empty hash' do
            expect(GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter).not_to receive(:new)

            expect(attributes).to eq({})
          end
        end

        context 'when context is a sub-group' do
          let(:context) { build_stubbed(:group, :nested) }

          it 'returns empty hash' do
            expect(GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter).not_to receive(:new)

            expect(attributes).to eq({})
          end
        end
      end

      context 'when user is not a member' do
        let(:authorized?) { false }
        let(:request_authorized?) { false }

        it 'returns empty hash' do
          expect(GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter).not_to receive(:new)

          expect(attributes).to eq({})
        end
      end
    end
  end
end
