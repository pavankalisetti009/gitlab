# frozen_string_literal: true

RSpec.shared_context 'with fetch_model_definitions_example' do
  let_it_be(:fetch_model_definitions_example) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet', 'identifier' => 'claude-sonnet', 'provider' => 'Anthropic' },
        { 'name' => 'GPT-4', 'identifier' => 'gpt-4', 'provider' => 'OpenAI' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        },
        {
          'feature_setting' => 'code_completions',
          'default_model' => 'gpt-4',
          'selectable_models' => %w[gpt-4],
          'beta_models' => []
        }
      ]
    }
  end
end

RSpec.shared_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService' do
  include_context 'with fetch_model_definitions_example'

  let_it_be(:successful_model_definitions_service_response) do
    ServiceResponse.success(payload: fetch_model_definitions_example)
  end

  let_it_be(:error_model_definitions_service_response) do
    ServiceResponse.error(payload: nil, message: 'Something went wrong')
  end

  let(:model_definitions_service_response) { successful_model_definitions_service_response }

  before do
    allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
      allow(service).to receive(:execute).and_return(model_definitions_service_response)
    end
  end
end
