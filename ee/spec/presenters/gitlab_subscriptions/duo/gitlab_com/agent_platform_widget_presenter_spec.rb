# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::GitlabCom::AgentPlatformWidgetPresenter, :aggregate_failures, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:namespace) { build_stubbed(:group) }
    let(:feature_enabled?) { true }
    let(:trial?) { false }
    let(:duo_core_features_available?) { true }
    let(:agent_fully_enabled?) { true }
    let(:enabled_without_beta_features?) { false }
    let(:only_duo_default_off?) { false }
    let(:enabled_without_core?) { false }
    let(:has_requested_access?) { false }
    let(:requestable?) { true }

    subject(:presenter) { described_class.new(user, namespace) }

    before do
      stub_feature_flags(duo_agent_platform_widget_gitlab_com: feature_enabled?)
      allow(namespace).to receive_messages(licensed_duo_core_features_available?: duo_core_features_available?)
      allow(GitlabSubscriptions::Duo).to(
        receive_messages(
          agent_fully_enabled?: agent_fully_enabled?,
          enabled_without_beta_features?: enabled_without_beta_features?,
          only_duo_default_off?: only_duo_default_off?,
          enabled_without_core?: enabled_without_core?,
          requestable?: requestable?
        )
      )
      allow(user).to receive(:dismissed_callout_for_group?).with(
        feature_name: 'duo_agent_platform_requested', group: namespace
      ).and_return(has_requested_access?)
    end

    context 'when not eligible' do
      context 'when feature flag is disabled' do
        let(:feature_enabled?) { false }

        it 'returns empty hash' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when namespace is on trial', :saas do
        before do
          build(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: namespace)
        end

        it 'returns empty hash' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when duo core features not available' do
        let(:duo_core_features_available?) { false }

        it 'returns empty hash' do
          expect(presenter.attributes).to eq({})
        end
      end
    end

    context 'when eligible' do
      context 'when not requestable' do
        let(:requestable?) { false }

        it 'returns attributes with showRequestAccess false' do
          results = {
            actionPath: ::Gitlab::Routing.url_helpers.request_duo_agent_platform_group_callouts_path(
              namespace_id: namespace.id
            ),
            contextualAttributes:
              {
                isAuthorized: false, showRequestAccess: false, hasRequested: false,
                requestText: s_('DuoAgentPlatform|Request has been sent to the group Owner')
              }
          }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when requestable' do
        let(:requestable?) { true }

        context 'when user has not requested access' do
          let(:has_requested_access?) { false }

          it 'returns attributes with showRequestAccess true and hasRequested false' do
            results = {
              actionPath: ::Gitlab::Routing.url_helpers.request_duo_agent_platform_group_callouts_path(
                namespace_id: namespace.id
              ),
              contextualAttributes:
                {
                  isAuthorized: false, showRequestAccess: true, hasRequested: false,
                  requestText: s_('DuoAgentPlatform|Request has been sent to the group Owner')
                }
            }
            expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
          end
        end

        context 'when user has already requested access' do
          let(:has_requested_access?) { true }

          it 'returns attributes with hasRequested true' do
            results = {
              actionPath: ::Gitlab::Routing.url_helpers.request_duo_agent_platform_group_callouts_path(
                namespace_id: namespace.id
              ),
              contextualAttributes:
                {
                  isAuthorized: false, showRequestAccess: true, hasRequested: true,
                  requestText: s_('DuoAgentPlatform|Request has been sent to the group Owner')
                }
            }
            expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
          end
        end
      end
    end
  end
end
