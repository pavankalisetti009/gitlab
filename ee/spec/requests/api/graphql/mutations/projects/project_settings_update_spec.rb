# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Project settings update", feature_category: :code_suggestions do
  include GraphqlHelpers
  include ProjectForksHelper
  include ExclusiveLeaseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:duo_features_enabled) { true }

  let(:duo_context_exclusion_settings) { nil }
  let(:mutation) do
    params = {
      full_path: project.full_path,
      duo_features_enabled: duo_features_enabled,
      duo_context_exclusion_settings: duo_context_exclusion_settings
    }.compact

    graphql_mutation(:project_settings_update, params) do
      <<-QL.strip_heredoc
        projectSettings {
          duoFeaturesEnabled
          duoContextExclusionSettings {
            exclusionRules
          }
        }
        errors
      QL
    end
  end

  context 'when updating settings' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_saas_features(duo_chat_on_saas: true)
    end

    it 'will update the settings' do
      post_graphql_mutation(mutation, current_user: user)
      expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings'])
               .to eq({ 'duoFeaturesEnabled' => duo_features_enabled,
                        'duoContextExclusionSettings' => { 'exclusionRules' => nil } })
    end

    context 'when updating duo_context_exclusion_settings' do
      let(:duo_context_exclusion_settings) { { exclusion_rules: ['*.txt', 'node_modules/'] } }

      it 'will update the duo context exclusion settings' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings']['duoContextExclusionSettings'])
          .to eq({ 'exclusionRules' => ['*.txt', 'node_modules/'] })
      end
    end

    context 'when no arguments are provided' do
      let(:duo_features_enabled) { nil }
      let(:empty_mutation) do
        graphql_mutation(:project_settings_update, { full_path: project.full_path }) do
          <<-QL.strip_heredoc
            projectSettings {
              duoFeaturesEnabled
            }
            errors
          QL
        end
      end

      it 'returns an error' do
        post_graphql_mutation(empty_mutation, current_user: user)

        expect(graphql_errors).to include(a_hash_including(
          'message' => 'Must provide at least one argument'
        ))
      end
    end
  end
end
