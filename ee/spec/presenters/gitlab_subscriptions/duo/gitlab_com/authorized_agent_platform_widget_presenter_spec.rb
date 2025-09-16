# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::GitlabCom::AuthorizedAgentPlatformWidgetPresenter, :aggregate_failures, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:namespace) { build_stubbed(:group) { |g| build(:namespace_settings, namespace: g) } }
    let(:feature_enabled?) { true }
    let(:trial?) { false }
    let(:duo_core_features_available?) { true }
    let(:agent_fully_enabled?) { true }
    let(:enabled_without_beta_features?) { false }
    let(:only_duo_default_off?) { false }
    let(:enabled_without_core?) { false }

    subject(:presenter) { described_class.new(user, namespace) }

    before do
      stub_feature_flags(duo_agent_platform_widget_gitlab_com: feature_enabled?)
      allow(namespace).to receive_messages(licensed_duo_core_features_available?: duo_core_features_available?)
      allow(GitlabSubscriptions::Duo).to(
        receive_messages(
          agent_fully_enabled?: agent_fully_enabled?,
          enabled_without_beta_features?: enabled_without_beta_features?,
          only_duo_default_off?: only_duo_default_off?,
          enabled_without_core?: enabled_without_core?
        )
      )
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
      include GrapePathHelpers::NamedRouteMatcher

      it 'returns all of the attributes' do
        results = {
          stateProgression: [:enabled],
          actionPath: api_v4_groups_path(id: namespace.id),
          initialState: :enabled,
          contextualAttributes:
            {
              featurePreviewAttribute: :experiment_features_enabled, isAuthorized: true, requestCount: 0,
              requestText:
                s_(
                  'DuoAgentPlatform|The number of users in your group who have requested access to GitLab Duo Core.'
                )
            }
        }
        expect(presenter.attributes[:duoAgentWidgetProvide]).to eq(results)
      end

      context 'when fully enabled' do
        it 'returns attributes with enabled state' do
          results = { stateProgression: [:enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when enabled without beta features' do
        let(:agent_fully_enabled?) { false }
        let(:enabled_without_beta_features?) { true }

        it 'returns attributes with enabled_without_beta_features state' do
          results = { stateProgression: [:enableFeaturePreview, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when only duo default off' do
        let(:agent_fully_enabled?) { false }
        let(:only_duo_default_off?) { true }

        it 'returns attributes with only_duo_default_off state' do
          results = { stateProgression: [:enablePlatform, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when enabled without core' do
        let(:agent_fully_enabled?) { false }
        let(:enabled_without_core?) { true }

        it 'returns attributes with enabled_without_core state' do
          results = { stateProgression: [:enablePlatform, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when disabled' do
        let(:agent_fully_enabled?) { false }
        let(:enabled_without_beta_features?) { false }
        let(:only_duo_default_off?) { false }

        it 'returns attributes with disabled state' do
          results = {
            stateProgression: [:enablePlatform, :enableFeaturePreview, :enabled],
            actionPath: "/api/v4/groups/#{namespace.id}"
          }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end
    end
  end
end
