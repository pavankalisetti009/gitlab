# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of configurable AI feature with metadata.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  include_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService'

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let(:query) do
    %(
      query aiFeatureSettings {
        aiFeatureSettings {
          nodes {
            feature
            title
            mainFeature
            compatibleLlms
            provider
            releaseState
            selfHostedModel {
              id
              name
              model
              modelDisplayName
              releaseState
            }
            validModels {
              nodes {
                id
                name
                model
                modelDisplayName
                releaseState
              }
            }
            defaultGitlabModel {
              ref
              name
              modelProvider
              modelDescription
            }
            gitlabModel {
              ref
              name
              modelProvider
              modelDescription
            }
            validGitlabModels {
              nodes {
                ref
                name
                modelProvider
                modelDescription
              }
            }
          }
        }
      }
    )
  end

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :code_completions,
      provider: :self_hosted
    )
  end

  let(:ai_feature_settings_data) { graphql_data_at(:aiFeatureSettings, :nodes) }

  let(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      glab_ask_git_command: 2
    }
  end

  let_it_be(:generation_feature_setting) do
    create(:ai_feature_setting, self_hosted_model: nil, feature: :code_generations, provider: :vendored)
  end

  let(:model_name_mapper) { ::Admin::Ai::SelfHostedModelsHelper::MODEL_NAME_MAPPER }

  before do
    allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(test_ai_feature_enum)
  end

  context "for feature setting decorator" do
    before do
      allow(::Gitlab::Graphql::Representation::AiFeatureSetting).to receive(:decorate)
      .and_return(generate_feature_setting_data(feature_setting))
    end

    context 'with manage_self_hosted_models_settings check' do
      where(:allowed) do
        [
          true,
          false
        ]
      end

      with_them do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
            .with(current_user, :manage_self_hosted_models_settings)
            .and_return(allowed)
        end

        it "decorates with_self_hosted_models: #{params[:allowed]}" do
          post_graphql(query, current_user: current_user)

          expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
            .to have_received(:decorate)
            .with(
              anything,
              hash_including(with_self_hosted_models: allowed)
            )
        end
      end
    end

    context 'with manage_instance_model_selection check' do
      where(:allowed) do
        [
          true,
          false
        ]
      end

      with_them do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
            .with(current_user, :manage_instance_model_selection)
            .and_return(allowed)
        end

        it "decorates with_gitlab_models: #{params[:allowed]}" do
          post_graphql(query, current_user: current_user)

          expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
            .to have_received(:decorate)
            .with(
              anything,
              hash_including(with_gitlab_models: allowed)
            )
        end
      end
    end
  end

  context 'when no query parameters are given' do
    let(:expected_response) do
      test_ai_feature_enum.keys.map do |feature|
        feature_setting = ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)

        generate_feature_setting_data(feature_setting)
      end
    end

    it 'returns the expected response' do
      post_graphql(query, current_user: current_user)

      result = ai_feature_settings_data

      expect(result).to match_array(expected_response)
    end
  end

  context 'when an Self-hosted model ID query parameters are given' do
    let(:query) do
      %(
          query aiFeatureSettings {
            aiFeatureSettings(selfHostedModelId: "#{model_gid}") {
              nodes {
                feature
                title
                mainFeature
                compatibleLlms
                provider
                releaseState
                selfHostedModel {
                  id
                  name
                  model
                  modelDisplayName
                  releaseState
                }
                validModels {
                  nodes {
                    id
                    name
                    model
                    modelDisplayName
                    releaseState
                  }
                }
                defaultGitlabModel {
                  ref
                  name
                  modelProvider
                  modelDescription
                }
                gitlabModel {
                  ref
                  name
                  modelProvider
                  modelDescription
                }
                validGitlabModels {
                  nodes {
                    ref
                    name
                    modelProvider
                    modelDescription
                  }
                }
              }
            }
          }
        )
    end

    context 'when the self-hosted model id exists' do
      let(:model_gid) { self_hosted_model.to_global_id }

      let(:expected_response) do
        [generate_feature_setting_data(feature_setting)]
      end

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(ai_feature_settings_data).to match_array(expected_response)
      end
    end

    context 'when the self-hosted model id does not exist' do
      let(:model_gid) { "gid://gitlab/Ai::SelfHostedModel/999999" }

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(ai_feature_settings_data).to be_empty
      end
    end
  end

  context 'when FetchModelDefinitionsService returns error ServiceResponse' do
    before do
      error_service = instance_double(::Ai::ModelSelection::FetchModelDefinitionsService)
      allow(::Ai::ModelSelection::FetchModelDefinitionsService).to receive(:new).and_return(error_service)
      allow(error_service).to receive(:execute).and_return(
        ServiceResponse.success(payload: nil)
      )

      stub_application_setting(duo_features_enabled: false)
    end

    it 'handles ServiceResponse gracefully without crashing' do
      expect { post_graphql(query, current_user: current_user) }.not_to raise_error
      expect(graphql_errors).to be_nil
    end
  end

  context 'when FetchModelDefinitionsService returns selectable GitLab models for glab_ask_git_command' do
    let(:model_definitions) do
      {
        'models' => [
          {
            'name' => 'GPT-4',
            'identifier' => 'gpt-4',
            "provider" => "OpenAI",
            "description" => 'For high-volume coding, reasoning, and routine workflows.'
          }
        ],
        'unit_primitives' => [
          { 'feature_setting' => 'code_generations', 'selectable_models' => %w[gpt-4] },
          { 'feature_setting' => 'code_completions', 'selectable_models' => %w[gpt-4] },
          { 'feature_setting' => 'glab_ask_git_command', 'selectable_models' => %w[gpt-4] }
        ]
      }
    end

    before do
      model_definitions_service = instance_double(::Ai::ModelSelection::FetchModelDefinitionsService)
      allow(::Ai::ModelSelection::FetchModelDefinitionsService).to receive(:new).and_return(model_definitions_service)
      allow(model_definitions_service).to receive(:execute).and_return(
        ServiceResponse.success(payload: model_definitions)
      )
    end

    it 'does not include the selectable models in the response' do
      post_graphql(query, current_user: current_user)

      result = ai_feature_settings_data.index_by { |node| node['feature'] }
      expected_valid_gitlab_model = {
        'name' => 'GPT-4',
        'ref' => 'gpt-4',
        'modelProvider' => "OpenAI",
        'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.'
      }

      expect(result.dig('glab_ask_git_command', 'validGitlabModels', 'nodes')).to be_empty

      %w[code_generations code_completions].each do |feature|
        expect(result.dig(feature, 'validGitlabModels', 'nodes')).to contain_exactly(expected_valid_gitlab_model)
      end
    end
  end

  def generate_feature_setting_data(feature_setting)
    gitlab_data = if feature_setting.feature.to_s == 'code_completions'
                    {
                      'defaultGitlabModel' => {
                        'name' => 'GPT-4',
                        'ref' => 'gpt-4',
                        'modelProvider' => 'OpenAI',
                        'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.'
                      },
                      'gitlabModel' => nil,
                      'validGitlabModels' => {
                        'nodes' => [
                          {
                            'name' => 'GPT-4',
                            'ref' => 'gpt-4',
                            'modelProvider' => 'OpenAI',
                            'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.'
                          }
                        ]
                      }
                    }
                  else
                    {
                      'defaultGitlabModel' => nil,
                      'gitlabModel' => nil,
                      'validGitlabModels' => { 'nodes' => [] }
                    }
                  end

    {
      'feature' => feature_setting.feature.to_s,
      'title' => feature_setting.title,
      'mainFeature' => feature_setting.main_feature,
      'compatibleLlms' => feature_setting.compatible_llms,
      'provider' => feature_setting.provider.to_s,
      'releaseState' => feature_setting.release_state,
      'selfHostedModel' => generate_self_hosted_data(feature_setting.self_hosted_model),
      'validModels' => {
        'nodes' => feature_setting.compatible_self_hosted_models.map { |s| generate_self_hosted_data(s) }
      },
      **gitlab_data
    }
  end

  def generate_self_hosted_data(self_hosted_model)
    return unless self_hosted_model

    {
      'id' => self_hosted_model.to_global_id.to_s,
      'name' => self_hosted_model.name,
      'model' => self_hosted_model.model,
      'modelDisplayName' => model_name_mapper[self_hosted_model.model],
      'releaseState' => self_hosted_model.release_state
    }
  end
end
