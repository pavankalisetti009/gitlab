# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::SelfManaged::AuthorizedAgentPlatformWidgetPresenter, :aggregate_failures, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:duo_core_features_available?) { true }
    let(:self_managed_agent_fully_enabled?) { true }
    let(:self_managed_enabled_without_beta_features?) { false }
    let(:self_managed_only_duo_default_off?) { false }
    let(:self_managed_enabled_without_core?) { false }
    let(:current_date) { Date.new(2025, 9, 18) }

    subject(:presenter) { described_class.new(user) }

    around do |example|
      travel_to(current_date)
      example.run
      travel_back
    end

    before do
      stub_licensed_features(code_suggestions: duo_core_features_available?)
      allow(GitlabSubscriptions::Duo).to(
        receive_messages(
          self_managed_agent_fully_enabled?: self_managed_agent_fully_enabled?,
          self_managed_enabled_without_beta_features?: self_managed_enabled_without_beta_features?,
          self_managed_only_duo_default_off?: self_managed_only_duo_default_off?,
          self_managed_enabled_without_core?: self_managed_enabled_without_core?
        )
      )
    end

    context 'when not eligible' do
      let(:duo_core_features_available?) { false }

      it 'returns empty hash' do
        expect(presenter.attributes).to eq({})
      end
    end

    context 'when eligible' do
      before do
        allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
        allow(Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('')
        stub_application_setting(gitlab_dedicated_instance: false)
      end

      context 'when fully enabled' do
        it 'returns attributes with enabled state' do
          results = { stateProgression: [:enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when enabled without beta features' do
        let(:self_managed_agent_fully_enabled?) { false }
        let(:self_managed_enabled_without_beta_features?) { true }

        it 'returns attributes with enabled_without_beta_features state' do
          results = { stateProgression: [:enableFeaturePreview, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when only duo default off' do
        let(:self_managed_agent_fully_enabled?) { false }
        let(:self_managed_only_duo_default_off?) { true }

        it 'returns attributes with only_duo_default_off state' do
          results = { stateProgression: [:enablePlatform, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when enabled without core' do
        let(:self_managed_agent_fully_enabled?) { false }
        let(:self_managed_enabled_without_core?) { true }

        it 'returns attributes with enabled_without_core state' do
          results = { stateProgression: [:enablePlatform, :enabled] }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when disabled' do
        let(:self_managed_agent_fully_enabled?) { false }
        let(:self_managed_enabled_without_beta_features?) { false }
        let(:self_managed_only_duo_default_off?) { false }

        it 'returns attributes with disabled state' do
          results = {
            stateProgression: [:enablePlatform, :enableFeaturePreview, :enabled],
            actionPath: ::Gitlab::Routing.url_helpers.update_duo_agent_platform_admin_application_settings_path
          }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end
    end

    context 'for eligibility checks' do
      context 'when before release date' do
        let(:current_date) { Date.new(2025, 9, 17) }

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when amazon q customer' do
        before do
          allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
        end

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when self hosted ai gateway' do
        before do
          allow(Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('http://some-host')
        end

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when dedicated pub sec customer' do
        before do
          stub_application_setting(gitlab_dedicated_instance: true)
        end

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when duo core features not available' do
        let(:duo_core_features_available?) { false }

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end
    end
  end
end
