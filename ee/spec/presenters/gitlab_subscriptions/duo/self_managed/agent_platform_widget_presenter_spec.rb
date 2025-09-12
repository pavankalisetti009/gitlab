# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::SelfManaged::AgentPlatformWidgetPresenter, :aggregate_failures, feature_category: :activation do
  describe '#attributes' do
    let(:user) { build_stubbed(:user) }
    let(:duo_core_features_available?) { true }
    let(:current_date) { Date.new(2025, 9, 18) }
    let(:has_requested_access?) { false }
    let(:self_managed_requestable?) { true }

    subject(:presenter) { described_class.new(user) }

    around do |example|
      travel_to(current_date)
      example.run
      travel_back
    end

    before do
      allow(License).to receive(:duo_core_features_available?).and_return(duo_core_features_available?)
      allow(::Feature).to receive(:disabled?).and_return(false)
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
      allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
      allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)

      allow(user).to receive(:dismissed_callout?)
                       .with(feature_name: 'duo_agent_platform_requested')
                       .and_return(has_requested_access?)

      allow(GitlabSubscriptions::Duo).to receive(:self_managed_requestable?).and_return(self_managed_requestable?)
    end

    context 'when not eligible' do
      let(:duo_core_features_available?) { false }

      it 'returns empty hash' do
        expect(presenter.attributes).to eq({})
      end
    end

    context 'when eligible' do
      context 'when not requestable' do
        let(:self_managed_requestable?) { false }

        it 'returns attributes with showRequestAccess false' do
          results = {
            actionPath: '/-/users/callouts/request_duo_agent_platform',
            contextualAttributes:
              {
                isAuthorized: false, showRequestAccess: false, hasRequested: false
              }
          }
          expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
        end
      end

      context 'when requestable' do
        let(:self_managed_requestable?) { true }

        context 'when user has not requested access' do
          let(:has_requested_access?) { false }

          it 'returns attributes with showRequestAccess true and hasRequested false' do
            results = {
              actionPath: '/-/users/callouts/request_duo_agent_platform',
              contextualAttributes:
                {
                  isAuthorized: false, showRequestAccess: true, hasRequested: false
                }
            }
            expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
          end
        end

        context 'when user has already requested access' do
          let(:has_requested_access?) { true }

          it 'returns attributes with hasRequested true' do
            results = {
              actionPath: '/-/users/callouts/request_duo_agent_platform',
              contextualAttributes:
                {
                  isAuthorized: false, showRequestAccess: true, hasRequested: true
                }
            }
            expect(presenter.attributes[:duoAgentWidgetProvide]).to match(a_hash_including(results))
          end
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

      context 'when duo_agent_platform_widget_self_managed feature flag is disabled' do
        before do
          allow(::Feature).to receive(:disabled?).with(:duo_agent_platform_widget_self_managed,
            :instance).and_return(true)
        end

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
          allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return('http://some-host')
        end

        it 'is not eligible' do
          expect(presenter.attributes).to eq({})
        end
      end

      context 'when dedicated instance' do
        before do
          allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
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
