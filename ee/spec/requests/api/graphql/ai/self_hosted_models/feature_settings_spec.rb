# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.aiSelfHostedModelFeatureSettings', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let(:fields) { 'edges { node { feature provider } }' }

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:feature_setting) do
    create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :code_completions,
      provider: :self_hosted)
  end

  let(:self_hosted_model_id) { global_id_of(self_hosted_model) }

  let(:expected_response) do
    [
      {
        'feature' => 'code_completions',
        'provider' => 'self_hosted'
      }
    ]
  end

  let(:query) do
    graphql_query_for(
      :aiSelfHostedModelFeatureSettings, { self_hosted_model_id: self_hosted_model_id },
      fields
    )
  end

  shared_examples 'a successful response' do
    it 'returns the expected response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['aiSelfHostedModelFeatureSettings']['edges']).to match_array(
        expected_response.map { |data| { 'node' => data } }
      )
    end
  end

  shared_examples 'an error response' do |expected_error_message|
    it 'returns an error' do
      post_graphql(query, current_user: current_user)
      expect(graphql_data['aiSelfHostedModelFeatureSettings']).to be_nil
      expect_graphql_errors_to_include(expected_error_message)
    end
  end

  context "when the user is authorized" do
    context 'when the feature flag is enabled' do
      it_behaves_like 'a successful response'
    end

    context 'when the ai_custom_model FF is disabled' do
      before do
        stub_feature_flags(ai_custom_model: false)
      end

      it_behaves_like 'an error response', "The 'ai_custom_model' feature is not enabled."
    end
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    let(:query) do
      graphql_query_for(
        :aiSelfHostedModelFeatureSettings, { self_hosted_model_id: self_hosted_model_id },
        fields
      )
    end

    it 'does not return feture settings' do
      post_graphql(query, current_user: current_user)
      expect(graphql_data['aiSelfHostedModelFeatureSettings']).to be_nil
    end
  end

  context 'when the self-hosted model does not exist' do
    let(:query) do
      graphql_query_for(
        :aiSelfHostedModelFeatureSettings,
        { self_hosted_model_id: global_id_of(id: non_existing_record_id, model_name: 'Ai::SelfHostedModel') },
        fields
      )
    end

    it_behaves_like 'an error response', 'The specified self-hosted model does not exist.'
  end
end
