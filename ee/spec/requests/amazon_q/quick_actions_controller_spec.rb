# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AmazonQ::QuickActionsController, feature_category: :ai_agents do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, duo_features_enabled: true) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:note) { create(:note, project: project, noteable: merge_request) }

  before do
    allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)

    sign_in(user)
  end

  describe 'POST #quick_actions' do
    let(:command) { '/amazon_q some command' }
    let(:params) { { note_id: note.id, command: command } }

    subject(:post_create) { post "/-/amazon_q/quick_actions", params: params }

    context 'when user is not authorized' do
      before_all do
        project.add_guest(user)
      end

      it 'returns unauthorized status' do
        post_create

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(::Gitlab::Json.parse(response.body)['error']).to eq('Unauthorized')
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_developer(user)
      end

      context 'when command is invalid' do
        before do
          allow_next_instance_of(Ai::AmazonQValidateCommandSourceService) do |instance|
            allow(instance).to receive(:validate)
                      .and_raise(Ai::AmazonQValidateCommandSourceService::UnsupportedCommandError, 'Invalid command')
          end
        end

        it 'returns unprocessable_entity status with error message' do
          post_create

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(::Gitlab::Json.parse(response.body)['error']).to eq('Invalid command')
        end
      end

      context 'when command is valid' do
        let(:amazon_q_trigger_service) { instance_double(Ai::AmazonQ::AmazonQTriggerService) }

        before do
          allow(Ai::AmazonQ::AmazonQTriggerService).to receive(:new).and_return(amazon_q_trigger_service)
          allow(amazon_q_trigger_service).to receive(:execute)

          allow_next_instance_of(Ai::AmazonQValidateCommandSourceService) do |instance|
            allow(instance).to receive(:validate)
          end
        end

        it 'executes the AmazonQ command' do
          expect(Ai::AmazonQ::AmazonQTriggerService).to receive(:new).with(
            user: user,
            command: command,
            source: merge_request,
            note: note,
            input: "",
            discussion_id: note.discussion_id
          )
          expect(amazon_q_trigger_service).to receive(:execute)

          post_create

          expect(response).to have_gitlab_http_status(:success)
        end
      end
    end
  end
end
