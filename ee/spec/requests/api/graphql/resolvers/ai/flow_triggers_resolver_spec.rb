# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FlowTriggersResolver, :with_current_organization, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be(:triggers) { create_list(:ai_flow_trigger, 3, project: project) }
  let_it_be(:other_project) { create(:project, maintainers: maintainer) }
  let_it_be(:other_trigger) { create(:ai_flow_trigger, project: other_project) }
  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:nodes) { graphql_data_at(:project, :ai_flow_triggers, :nodes) }
  let(:current_user) { maintainer }
  let(:args) { '' }

  let(:query) do
    <<~GQL
      {
        project(fullPath: "#{project.full_path}") {
          aiFlowTriggers#{args} {
            nodes {
              id
            }
          }
        }
      }
    GQL
  end

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    ::Ai::Setting.instance.update!(duo_core_features_enabled: true)
    stub_ee_application_setting(duo_features_enabled: true)
  end

  context 'when developer' do
    let(:current_user) do
      create(:user).tap { |user| project.add_reporter(user) }
    end

    it 'returns no flow triggers' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to be_empty
    end
  end

  it 'returns all flow triggers for project' do
    post_graphql(query, current_user: current_user)

    expect(nodes).to match_array(
      triggers.map { |trigger| a_graphql_entity_for(trigger) }
    )
  end

  context 'when ids argument present' do
    let(:args) do
      <<~GQL
        (ids: [
          "#{triggers[0].to_global_id}",
          "#{triggers[1].to_global_id}",
          "#{other_trigger.to_global_id}"
        ])
      GQL
    end

    it 'returns flow triggers for project with ids' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to contain_exactly(a_graphql_entity_for(triggers[0]), a_graphql_entity_for(triggers[1]))
    end
  end
end
