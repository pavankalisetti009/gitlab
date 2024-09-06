# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::StartWorkflowService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:user) { create(:user, developer_of: project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:params) { {} }

    subject(:execute) do
      described_class
        .new(workflow: workflow, params: params)
        .execute
    end

    context 'when FF is disabled' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it 'does not start a workflow' do
        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when ci pipeline could not be created' do
      let(:pipeline) do
        instance_double('Ci::Pipeline', created_successfully?: false, full_error_messages: 'full error messages')
      end

      let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

      before do
        allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
          allow(instance).to receive(:execute).and_return(service_response)
        end
      end

      it 'does not start a pipeline to execute workflow' do
        expect(execute).to be_error
        expect(execute[:reason]).to eq(:bad_request)
        expect(execute[:message]).to eq('Pipeline creation failed')
      end
    end

    context 'when pipeline creation is success' do
      let(:params) do
        {
          goal: 'Print Hello world',
          workflow_id: workflow.id,
          workflow_oauth_token: 'a-valid-token',
          workflow_service_token: 'an-encrypted-token'
        }
      end

      it 'starts a pipeline to execute workflow' do
        expect_next_instance_of(Ci::CreatePipelineService, project, user,
          hash_including(ref: project.default_branch_or_main)) do |pipeline_service|
          expect(pipeline_service).to receive(:execute)
            .and_call_original
        end
        expect(execute).to be_success
        expect(execute[:pipeline]).not_to be(nil)
      end
    end
  end
end
