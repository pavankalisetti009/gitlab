# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettingSelectionService, feature_category: :"self-hosted_models" do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:code_completions_ai_feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :code_completions
    )
  end

  let(:feature) { :duo_chat }
  let(:service) { described_class.new(user, feature, root_namespace) }

  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
  end

  describe '#execute' do
    subject(:response) { service.execute }

    before do
      allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(default_duo_namespace)
    end

    let(:default_duo_namespace) { root_namespace }

    context 'when AmazonQ is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      it 'returns success with nil payload' do
        expect(response).to be_success
        expect(response.payload).to be_nil
      end
    end

    context 'when running on GitLab.com or GitLab.org' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when root_namespace is provided' do
        context 'when feature setting does not exist' do
          it 'returns success with namespace feature setting' do
            expect(response).to be_success
            expect(response.payload).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
            expect(response.payload.namespace).to eq(root_namespace)
            expect(response.payload.feature).to eq(feature.to_s)
          end
        end

        context 'when feature setting already exists' do
          let!(:existing_setting) do
            create(:ai_namespace_feature_setting, namespace: root_namespace, feature: feature,
              offered_model_ref: "claude-3-7-sonnet-20250219")
          end

          it 'returns the existing feature setting' do
            expect(response).to be_success
            expect(response.payload).to eq(existing_setting)
          end
        end
      end

      context 'when root_namespace is nil' do
        let(:root_namespace) { nil }

        context 'when user has a default duo namespace' do
          let(:default_duo_namespace) { create(:group) }

          it 'returns success with namespace feature setting for default namespace' do
            expect(response).to be_success
            expect(response.payload).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
            expect(response.payload.namespace).to eq(default_duo_namespace)
            expect(response.payload.feature).to eq(feature.to_s)
          end
        end

        context 'when user has no default duo namespace' do
          let(:default_duo_namespace) { nil }

          context 'when default duo namespace is required' do
            before do
              allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(true)
            end

            it 'returns error with missing default namespace message' do
              expect(response).to be_error
              expect(response.message).to eq(described_class::MISSING_DEFAULT_NAMESPACE)
            end
          end

          context 'when default duo namespace is not required' do
            before do
              allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(false)
            end

            it 'returns success with nil payload' do
              expect(response).to be_success
              expect(response.payload).to be_nil
            end
          end
        end
      end
    end

    context 'when running on self-hosted instance' do
      context 'when self-hosted feature setting exists' do
        let_it_be(:ai_feature_setting) do
          create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat)
        end

        it 'returns success with self-hosted feature setting' do
          expect(response).to be_success
          expect(response.payload).to eq(ai_feature_setting)
        end
      end

      context 'when self-hosted feature setting exists and is vendored' do
        let_it_be(:vendored_feature_setting) do
          create(:ai_feature_setting, feature: :duo_chat, provider: :vendored)
        end

        it 'returns success with vendored feature setting' do
          expect(response).to be_success
          expect(response.payload).to eq(vendored_feature_setting)
        end
      end

      context 'when self-hosted feature setting does not exist' do
        it 'returns success with self-hosted feature setting' do
          expect(response).to be_success
          expect(response.payload).to be_nil
        end
      end
    end
  end
end
