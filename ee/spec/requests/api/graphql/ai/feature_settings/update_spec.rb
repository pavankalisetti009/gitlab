# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an AI Feature setting', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  include_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService'

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :vendored, self_hosted_model: nil) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed) }

  let(:mutation_name) { :ai_feature_setting_update }
  let(:mutation_params) do
    {
      features: ['CODE_GENERATIONS'],
      provider: 'VENDORED'
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the user does not have write access' do
      let(:current_user) { create(:user) }

      context "for self-hosted models" do
        let(:self_hosted_model_id) { self_hosted_model.to_global_id.to_s }
        let(:mutation_params) do
          {
            features: ['CODE_GENERATIONS'],
            provider: 'SELF_HOSTED',
            ai_self_hosted_model_id: self_hosted_model_id
          }
        end

        it_behaves_like 'performs the right authorization'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting ai_self_hosted_model_id."
          )
        end
      end

      context "for gitlab managed models" do
        let(:self_hosted_model_id) { self_hosted_model.to_global_id.to_s }
        let(:mutation_params) do
          {
            features: ['CODE_GENERATIONS'],
            provider: 'VENDORED',
            offered_model_ref: 'claude_3_5_sonnet_20240620'
          }
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, :manage_instance_model_selection)
          request
        end

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting offered_model_ref."
          )
        end
      end
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'

      context 'when there are ActiveRecord validation errors' do
        let(:mutation_params) do
          {
            features: ['CODE_GENERATIONS'],
            provider: 'SELF_HOSTED'
          }
        end

        it 'returns an error' do
          request
          result = json_response['data']['aiFeatureSettingUpdate']
          expect(result['aiFeatureSettings']).to eq([])
          expect(result['errors']).to eq(["Self hosted model can't be blank"])
        end

        it 'does not update the AI feature setting' do
          request
          expect(feature_setting.reload.provider).to eq("vendored")
        end
      end

      context 'when features array is empty' do
        let(:mutation_params) do
          {
            features: [],
            provider: 'VENDORED'
          }
        end

        it 'returns an error message' do
          request
          result = json_response['data']['aiFeatureSettingUpdate']

          expect(result['aiFeatureSettings']).to eq([])
          expect(result['errors']).to eq(['At least one feature is required'])
        end
      end

      context 'when there are no errors' do
        let(:self_hosted_model_id) { self_hosted_model.to_global_id.to_s }
        let(:mutation_params) do
          {
            features: %w[CODE_GENERATIONS DUO_CHAT],
            provider: 'SELF_HOSTED',
            ai_self_hosted_model_id: self_hosted_model_id
          }
        end

        context 'when the feature setting exists' do
          before do
            create(:ai_feature_setting, feature: 'duo_chat', provider: :vendored, self_hosted_model: nil)
          end

          it 'updates the feature settings correctly' do
            expect { request }.not_to change { ::Ai::FeatureSetting.count }
            expect(response).to have_gitlab_http_status(:success)

            feature_settings = ::Ai::FeatureSetting.where(feature: %w[code_generations duo_chat]).order(:feature)

            expect(feature_settings.count).to eq(2)

            feature_settings.each do |setting|
              expect(setting.reload.provider).to eq('self_hosted')
              expect(setting.reload.self_hosted_model.to_global_id.to_s).to eq(self_hosted_model_id)
            end
          end

          it 'returns a success response' do
            request

            result = json_response['data']['aiFeatureSettingUpdate']
            feature_settings_payload = result['aiFeatureSettings']

            expect(result['errors']).to eq([])
            expect(feature_settings_payload.length).to eq(2)
            expect(feature_settings_payload.first['feature']).to eq(feature_setting.feature)
            expect(feature_settings_payload.first['provider']).to eq(feature_setting.reload.provider)
            expect(feature_settings_payload.first['selfHostedModel']['id']).to eq(self_hosted_model_id)
          end

          it 'returns gitlab model information' do
            request

            result = json_response['data']['aiFeatureSettingUpdate']
            feature_setting_response = result['aiFeatureSettings'][1]

            expect(feature_setting_response['defaultGitlabModel']).to eq(
              { 'name' => 'Claude Sonnet',
                'ref' => 'claude-sonnet' }
            )
          end

          context 'when :instance_level_model_selection feature flag is off' do
            before do
              stub_feature_flags(instance_level_model_selection: false)
            end

            it 'does not make request for model definitions' do
              expect(::Ai::ModelSelection::FetchModelDefinitionsService).not_to receive(:new)
            end
          end
        end

        context 'when the feature setting does not exist' do
          let(:mutation_params) do
            {
              features: %w[DUO_CHAT_FIX_CODE DUO_CHAT_EXPLAIN_CODE],
              provider: 'SELF_HOSTED',
              ai_self_hosted_model_id: self_hosted_model_id
            }
          end

          before do
            ::Ai::FeatureSetting.delete_all
          end

          it 'creates the feature settings correctly' do
            expect { request }.to change { ::Ai::FeatureSetting.count }.from(0).to(2)
            expect(response).to have_gitlab_http_status(:success)

            feature_settings = ::Ai::FeatureSetting.where(feature: %w[duo_chat_fix_code
              duo_chat_explain_code]).order(:feature)

            expect(feature_settings.count).to eq(2)

            feature_settings.each do |setting|
              expect(setting.provider).to eq('self_hosted')
              expect(setting.self_hosted_model.to_global_id.to_s).to eq(self_hosted_model_id)
            end
          end
        end
      end
    end
  end
end
