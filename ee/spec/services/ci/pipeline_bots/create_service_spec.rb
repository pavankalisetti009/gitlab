# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineBots::CreateService, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let(:params) { { access_level: Gitlab::Access::DEVELOPER } }

  subject(:service) { described_class.new(project, current_user, params) }

  context 'when the current user is a maintainer' do
    let_it_be(:current_user) { create(:user, maintainer_of: project) }

    it 'rejects if the feature is not licensed' do
      service_response = service.execute
      expect(service_response.message).to eq("Pipeline bots feature not available")
    end

    context 'when the project has pipeline bot license' do
      before do
        stub_licensed_features(ci_pipeline_bots: true)
      end

      it 'creates a pipeline bot user' do
        service_response = service.execute

        expect(service_response.status).to eq(:success)

        user_payload = service_response.payload[:user]

        expect(user_payload.username).to start_with("project_#{project.id}_pipeline_bot")
        expect(user_payload.email).to start_with(user_payload.username)
        expect(user_payload.max_member_access_for_project(project.id)).to eq(Gitlab::Access::DEVELOPER)
        expect(user_payload).to have_attributes(
          name: "ci pipelines bot",
          confirmed?: true,
          user_type: "ci_pipeline_bot",
          external: false,
          password: nil
        )
      end

      context 'when name and access level parameters are passed in' do
        let(:params) { { access_level: Gitlab::Access::MAINTAINER, name: "nice bot" } }

        it 'creates a pipeline bot with given name' do
          service_response = service.execute
          expect(service_response.payload[:user].name).to eq("nice bot")
          expect(
            service_response.payload[:user].max_member_access_for_project(project.id)
          ).to eq(Gitlab::Access::MAINTAINER)
        end
      end

      context 'when an invalid access level parameter is passed in' do
        let(:params) { { access_level: Gitlab::Access::REPORTER } }

        it 'rejects pipeline bot creation' do
          service_response = service.execute
          expect(service_response.message).to eq("Bot must have either Developer or Maintainer permissions")
        end
      end

      context 'when something goes wrong with member creation' do
        before do
          member_double = instance_double(ProjectMember, persisted?: false)
          allow(member_double).to receive_message_chain(:errors, :full_messages, :to_sentence)
            .and_return("Could not add to project")
          allow(project).to receive(:add_member).and_return(member_double)
        end

        it 'triggers deletion of the user and returns and error response' do
          expect(DeleteUserWorker).to receive(:perform_async).with(
            current_user.id,
            anything,
            {
              hard_delete: true,
              reason_for_deletion: "Pipeline bot creation failed",
              skip_authorization: true
            }
          )

          service_response = service.execute
          expect(service_response.message)
            .to eq("Could not associate pipeline bot to project. ERROR: Could not add to project")
        end
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(create_and_use_ci_pipeline_bots: false)
      end

      it 'returns service error' do
        service_response = service.execute
        expect(service_response.message).to eq("Feature flag create_and_use_ci_pipeline_bots is disabled")
      end
    end
  end

  context 'when the current user does not have permission' do
    let_it_be(:current_user) { create(:user, developer_of: project) }

    before do
      stub_licensed_features(ci_pipeline_bots: true)
    end

    it 'returns insufficient permission error' do
      service_response = service.execute
      expect(service_response.message).to eq("User does not have permission to create pipeline bots")
    end
  end
end
