# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflow Events', feature_category: :duo_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:workflow) { create(:duo_workflows_workflow, project: project, user: user, checkpoints: checkpoints) }
  let(:checkpoints) { create_list(:duo_workflows_checkpoint, 3, project: project) }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        timestamp
        errors
        checkpoint,
        metadata,
        parentTimestamp,
        workflowGoal
      }
    GRAPHQL
  end

  let(:arguments) { { workflowId: global_id_of(workflow) } }
  let(:query) { graphql_query_for('duoWorkflowEvents', arguments, fields) }

  subject(:events) { graphql_data.dig('duoWorkflowEvents', 'nodes') }

  context 'when user is not logged in' do
    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(events).to be_empty
    end
  end

  context 'when user is logged in' do
    it 'returns user messages', :freeze_time do
      post_graphql(query, current_user: user)

      events.sort_by { |event| event['timestamp'] }.each_with_index do |event, i|
        expect(event['errors']).to eq([])
        expect(event['checkpoint']).to eq(checkpoints[i].checkpoint.to_json)
        expect(event['metadata']).to eq(checkpoints[i].metadata.to_json)
        expect(event['timestamp']).to eq(Time.parse(checkpoints[i].thread_ts).iso8601)
        expect(event['parentTimestamp']).to eq(Time.parse(checkpoints[i].parent_ts).iso8601)
        expect(event['workflowGoal']).to eq("Fix pipeline")
      end
    end
  end
end
