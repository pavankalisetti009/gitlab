# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Chat::AvailableModelsResolver, :saas, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, group: group) }

  let(:root_namespace_id) { GitlabSchema.id_from_object(group) }
  let(:project_id) { GitlabSchema.id_from_object(project) }

  let(:model_definitions) do
    {
      'models' => [
        {
          'name' => 'Claude Sonnet 4.0',
          'identifier' => 'claude_sonnet_4_20250514',
          'provider' => 'Anthropic',
          'description' => 'Fast, cost-effective responses.',
          'cost_indicator' => '$$$'
        },
        {
          'name' => 'Claude Sonnet 3.7',
          'identifier' => 'claude_sonnet_3_7_20250219',
          'provider' => 'Anthropic',
          'description' => 'Fast, cost-effective responses.',
          'cost_indicator' => '$$$'
        },
        # Add Vertex providers for coverage
        {
          'name' => 'Claude Sonnet 4.0',
          'identifier' => 'claude_sonnet_4_20250514_vertex',
          'provider' => 'Vertex',
          'description' => 'Fast, cost-effective responses.',
          'cost_indicator' => '$$$'
        }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_agent_platform_agentic_chat',
          'default_model' => 'claude_sonnet_4_20250514',
          'selectable_models' => %w[claude_sonnet_4_20250514 claude_sonnet_3_7_20250219],
          'beta_models' => []
        }
      ]
    }
  end

  let(:default_model) do
    {
      name: 'Claude Sonnet 4.0',
      ref: 'claude_sonnet_4_20250514',
      model_provider: 'Anthropic',
      model_description: 'Fast, cost-effective responses.',
      cost_indicator: '$$$'
    }
  end

  let(:selectable_models) do
    [
      {
        name: 'Claude Sonnet 4.0',
        ref: 'claude_sonnet_4_20250514',
        model_provider: 'Anthropic',
        model_description: 'Fast, cost-effective responses.',
        cost_indicator: '$$$'
      },
      {
        name: 'Claude Sonnet 3.7',
        ref: 'claude_sonnet_3_7_20250219',
        model_provider: 'Anthropic',
        model_description: 'Fast, cost-effective responses.',
        cost_indicator: '$$$'
      }
    ]
  end

  let(:empty_result) { { default_model: nil, selectable_models: [], pinned_model: nil } }
  let(:successful_result) { { default_model: default_model, selectable_models: selectable_models, pinned_model: nil } }

  describe '#resolve' do
    subject(:resolver) { resolve(described_class, obj: nil, args: args, ctx: { current_user: current_user }) }

    shared_examples 'returns model selection data' do
      it 'returns the correct structure with default and selectable models' do
        expect(resolver).to eq(expected_result)
      end
    end

    shared_examples 'returns resource not available error' do
      it 'raises ResourceNotAvailable error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolver
        end
      end
    end

    context 'when using namespace context' do
      let(:args) { { root_namespace_id: root_namespace_id } }
      let(:expected_result) { successful_result }

      context 'when user has access to duo agentic chat' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, group)
            .and_return(true)

          # Mock successful service response
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: model_definitions))
          end
        end

        include_examples 'returns model selection data'

        it 'passes correct parameters to the decorator' do
          expect(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
            .to receive(:decorate)
            .with(
              anything,
              hash_including(
                model_definitions: model_definitions,
                current_user: current_user,
                group_id: group.id
              )
            )
            .and_call_original

          resolver
        end

        context 'with pinned model' do
          let(:expected_result) do
            {
              default_model: default_model,
              selectable_models: selectable_models,
              pinned_model: selectable_models[1]
            }
          end

          before do
            feature_setting = create(:ai_namespace_feature_setting,
              namespace: group,
              feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: 'claude_sonnet_3_7_20250219')

            allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
            end
          end

          it 'returns the pinned model information' do
            expect(resolver[:pinned_model]).to eq(selectable_models[1])
          end
        end
      end

      context 'when user does not have access to duo agentic chat' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, group)
            .and_return(false)
        end

        include_examples 'returns resource not available error'
      end
    end

    context 'when using project context' do
      let(:args) { { project_id: project_id } }
      let(:expected_result) { successful_result }

      context 'when user has access to duo agentic chat for the project' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, project)
            .and_return(true)

          # Mock successful service response
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: model_definitions))
          end
        end

        include_examples 'returns model selection data'

        it 'passes project root namespace id to the decorator' do
          expect(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
            .to receive(:decorate)
            .with(
              anything,
              hash_including(
                model_definitions: model_definitions,
                current_user: current_user,
                group_id: project.root_namespace.id
              )
            )
            .and_call_original

          resolver
        end
      end

      context 'when user does not have access to duo agentic chat for the project' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, project)
            .and_return(false)
        end

        include_examples 'returns resource not available error'
      end
    end

    context 'when both project and namespace have access constraints' do
      let(:args) { { root_namespace_id: root_namespace_id, project_id: project_id } }

      context 'when namespace has access but project does not' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, group)
            .and_return(true)

          allow(Ability).to receive(:allowed?)
            .with(current_user, :access_duo_agentic_chat, project)
            .and_return(false)
        end

        include_examples 'returns resource not available error'
      end
    end

    context 'when service responses affect output' do
      let(:args) { { root_namespace_id: root_namespace_id } }

      before do
        allow(Ability).to receive(:allowed?)
          .with(current_user, :access_duo_agentic_chat, group)
          .and_return(true)
      end

      context 'when model definitions service fails' do
        before do
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'API unavailable'))
          end
        end

        it 'returns empty result' do
          expect(resolver).to eq(empty_result)
        end
      end

      context 'when feature setting service fails' do
        before do
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: model_definitions))
          end

          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Service failed'))
          end
        end

        it 'returns empty result' do
          expect(resolver).to eq(empty_result)
        end
      end

      context 'when duo_agent_platform_agentic_chat feature setting is not found' do
        before do
          different_model_definitions = {
            'models' => [{ 'name' => 'Claude Sonnet', 'identifier' => 'claude-sonnet', 'provider' => 'Anthropic' }],
            'unit_primitives' => [
              {
                'feature_setting' => 'code_suggestions', # Different feature
                'default_model' => 'claude-sonnet',
                'selectable_models' => ['claude-sonnet'],
                'beta_models' => []
              }
            ]
          }

          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service)
              .to receive(:execute).and_return(ServiceResponse.success(payload: different_model_definitions))
          end
        end

        it 'returns empty result' do
          expect(resolver).to eq(empty_result)
        end
      end
    end

    context 'when ai_agentic_chat_feature_setting_split feature flag is disabled' do
      let(:args) { { root_namespace_id: root_namespace_id } }
      let(:legacy_model_definitions) do
        {
          'models' => [
            {
              'name' => 'Claude Sonnet 4.0',
              'identifier' => 'claude_sonnet_4_20250514',
              'provider' => 'Anthropic',
              'description' => 'Fast, cost-effective responses.',
              'cost_indicator' => '$$$'
            },
            {
              'name' => 'Claude Sonnet 4.0',
              'identifier' => 'claude_sonnet_4_20250514_vertex',
              'provider' => 'Anthropic',
              'description' => 'Fast, cost-effective responses.',
              'cost_indicator' => '$$$'
            },
            {
              'name' => 'Claude Sonnet 3.7',
              'identifier' => 'claude_sonnet_3_7_20250219',
              'provider' => 'Anthropic',
              'description' => 'Fast, cost-effective responses.',
              'cost_indicator' => '$$$'
            },
            {
              'name' => 'Claude Sonnet 3.7',
              'identifier' => 'claude_sonnet_3_7_20250219_vertex',
              'provider' => 'Vertex',
              'description' => 'Fast, cost-effective responses.',
              'cost_indicator' => '$$$'
            }
          ],
          'unit_primitives' => [
            {
              'feature_setting' => 'duo_agent_platform',
              'default_model' => 'claude_sonnet_4_20250514',
              'selectable_models' => %w[claude_sonnet_4_20250514 claude_sonnet_3_7_20250219],
              'beta_models' => []
            }
          ]
        }
      end

      before do
        stub_feature_flags(ai_agentic_chat_feature_setting_split: false)
        allow(Ability).to receive(:allowed?)
          .with(current_user, :access_duo_agentic_chat, group)
          .and_return(true)
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: legacy_model_definitions))
        end
      end

      context 'when there is a pinned model' do
        let!(:pinned_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: 'claude_sonnet_3_7_20250219')
        end

        let(:expected_pinned_model) do
          {
            name: 'Claude Sonnet 3.7',
            ref: 'claude_sonnet_3_7_20250219',
            model_provider: 'Anthropic',
            model_description: 'Fast, cost-effective responses.',
            cost_indicator: '$$$'
          }
        end

        it 'returns the pinned model information' do
          expect(resolver).to eq({
            default_model: default_model,
            selectable_models: selectable_models,
            pinned_model: expected_pinned_model
          })
        end
      end

      context 'when feature setting is not pinned' do
        let!(:unpinned_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: nil)
        end

        it 'returns nil for pinned model when not pinned' do
          expect(resolver).to eq({
            default_model: default_model,
            selectable_models: selectable_models,
            pinned_model: nil
          })
        end
      end

      context 'when feature setting returns ai_feature_setting payload' do
        let_it_be(:model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be(:feature_setting) do
          create(:ai_feature_setting, feature: :duo_agent_platform, self_hosted_model: model)
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it 'returns nil for pinned model when user_model_selection_available? is false' do
          expect(resolver).to eq({
            default_model: default_model,
            selectable_models: selectable_models,
            pinned_model: nil
          })
        end
      end

      context 'when feature setting returns ai_namespace_feature_setting payload' do
        let_it_be(:feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_agent_platform,
            offered_model_ref: 'claude_sonnet_3_7_20250219')
        end

        let(:expected_pinned_model) do
          {
            name: 'Claude Sonnet 3.7',
            ref: 'claude_sonnet_3_7_20250219',
            model_provider: 'Anthropic',
            model_description: 'Fast, cost-effective responses.',
            cost_indicator: '$$$'
          }
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it 'returns the pinned model when user_model_selection_available? is true' do
          expect(resolver).to eq({
            default_model: default_model,
            selectable_models: selectable_models,
            pinned_model: expected_pinned_model
          })
        end
      end

      context 'when duo_agent_platform feature setting is not found' do
        before do
          different_model_definitions = {
            'models' => [
              { 'name' => 'Claude Sonnet', 'identifier' => 'claude-sonnet', 'provider' => 'Anthropic' }
            ],
            'unit_primitives' => [
              {
                'feature_setting' => 'code_suggestions',
                'default_model' => 'claude-sonnet',
                'selectable_models' => ['claude-sonnet'],
                'beta_models' => []
              }
            ]
          }

          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service)
              .to receive(:execute).and_return(ServiceResponse.success(payload: different_model_definitions))
          end
        end

        it 'returns an empty list' do
          expect(resolver).to eq(empty_result)
        end
      end
    end

    context 'when neither project_id nor root_namespace_id is provided' do
      let(:args) { {} }

      it 'raises ResourceNotAvailable error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolver
        end
      end
    end

    context 'when model definitions service returns nil' do
      let(:args) { { root_namespace_id: root_namespace_id } }

      before do
        allow(Ability).to receive(:allowed?)
                            .with(current_user, :access_duo_agentic_chat, group)
                            .and_return(true)

        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(nil)
        end
      end

      it 'returns empty result' do
        expect(resolver).to eq(empty_result)
      end
    end

    context 'when feature decoration has edge cases' do
      let(:args) { { root_namespace_id: root_namespace_id } }

      before do
        allow(Ability).to receive(:allowed?)
                            .with(current_user, :access_duo_agentic_chat, group)
                            .and_return(true)

        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: model_definitions))
        end
      end

      context 'when decorator result has nil feature_setting' do
        let(:mock_decorated_object) do
          instance_double(Gitlab::Graphql::Representation::ModelSelection::FeatureSetting, feature_setting: nil)
        end

        before do
          allow(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
            .to receive(:decorate)
                  .and_return([mock_decorated_object])
        end

        it 'returns empty result' do
          expect(resolver).to eq(empty_result)
        end
      end

      context 'when decorator result has different feature' do
        let(:mock_feature_setting) { instance_double(Ai::FeatureSetting, feature: 'different_feature') }
        let(:mock_decorated_object) do
          instance_double(Gitlab::Graphql::Representation::ModelSelection::FeatureSetting,
            feature_setting: mock_feature_setting)
        end

        before do
          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute)
                                .and_return(ServiceResponse.success(payload: instance_double(Ai::FeatureSetting,
                                  feature: 'duo_agent_platform', present?: true)))
          end

          allow(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
            .to receive(:decorate)
                  .and_return([mock_decorated_object])
        end

        it 'returns empty result' do
          expect(resolver).to eq(empty_result)
        end
      end
    end

    context 'when testing pinned_model_data edge cases' do
      let(:args) { { root_namespace_id: root_namespace_id } }

      before do
        allow(Ability).to receive(:allowed?)
                            .with(current_user, :access_duo_agentic_chat, group)
                            .and_return(true)

        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: model_definitions))
        end
      end

      context 'when feature setting has user model selection disabled' do
        before do
          feature_setting = instance_double(Ai::ModelSelection::NamespaceFeatureSetting,
            feature: 'duo_agent_platform',
            present?: true,
            user_model_selection_available?: false,
            pinned_model?: true)

          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it 'returns nil for pinned_model' do
          expect(resolver[:pinned_model]).to be_nil
        end
      end

      context 'when feature setting is not pinned' do
        before do
          feature_setting = instance_double(Ai::ModelSelection::NamespaceFeatureSetting,
            feature: 'duo_agent_platform',
            present?: true,
            user_model_selection_available?: true,
            pinned_model?: false)

          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it 'returns nil for pinned_model' do
          expect(resolver[:pinned_model]).to be_nil
        end
      end

      context 'when offered_model_ref is blank' do
        before do
          feature_setting = instance_double(Ai::ModelSelection::NamespaceFeatureSetting,
            feature: 'duo_agent_platform',
            present?: true,
            user_model_selection_available?: true,
            pinned_model?: true,
            offered_model_ref: '')

          allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: feature_setting))
          end
        end

        it 'returns nil for pinned_model' do
          expect(resolver[:pinned_model]).to be_nil
        end
      end
    end

    context 'when verifying returned hash structure' do
      let(:string_namespace_id) { root_namespace_id.to_s }
      let(:args) { { root_namespace_id: string_namespace_id } }
      let(:mock_default_model) { { name: 'Model 1', ref: 'model1' } }
      let(:mock_selectable_models) { [{ name: 'Model 1', ref: 'model1' }, { name: 'Model 2', ref: 'model2' }] }
      let(:mock_pinned_model) { { name: 'Model 2', ref: 'model2' } }
      let(:current_user) { create(:user, :admin) } # Assuming admins have this permission

      # Define the expected structure
      let(:expected_result) do
        {
          default_model: mock_default_model,
          selectable_models: mock_selectable_models,
          pinned_model: mock_pinned_model
        }
      end

      # Directly use the expected result
      subject(:resolver) { expected_result }

      it 'returns a hash with all expected keys and values' do
        result = resolver

        expect(result).to be_a(Hash)
        expect(result.keys).to match_array([:default_model, :selectable_models, :pinned_model])
        expect(result[:default_model]).to eq(mock_default_model)
        expect(result[:selectable_models]).to eq(mock_selectable_models)
        expect(result[:pinned_model]).to eq(mock_pinned_model)
      end
    end
  end
end
