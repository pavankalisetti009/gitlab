# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'merge requests creations', feature_category: :code_review_workflow do
  describe 'POST /:namespace/:project/merge_requests' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, :with_namespace, developer_of: group) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let(:merge_request) { MergeRequest.last }
    let(:create_merge_request_params) do
      {
        namespace_id: project.namespace.to_param,
        project_id: project,
        merge_request: {
          source_branch: 'feature',
          target_branch: 'master',
          title: 'Test merge request',
          description: description
        }
      }
    end

    subject(:send_request) do
      post namespace_project_merge_requests_path(create_merge_request_params)
    end

    before do
      login_as(user)
    end

    describe 'Duo code review assignment handling' do
      include_examples 'handle quickactions without Duo access'

      context 'when automatic Duo code review is enabled' do
        let(:duo_bot) { ::Users::Internal.duo_code_review_bot }
        let(:project) { create(:project, :repository, group: group) }
        let(:description) { "" }
        let(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

        before do
          authorization = instance_double(::Ai::CodeReviewAuthorization)
          allow(authorization).to receive(:allowed?).with(user).and_return(has_duo_access)
          allow(::Ai::CodeReviewAuthorization).to receive(:new).and_return(authorization)

          project.project_setting.update_attribute(:auto_duo_code_review_enabled, true)
          project.project_setting.update!(duo_features_enabled: true)
        end

        context 'with legacy flow (duo_code_review_on_agent_platform disabled)' do
          before do
            stub_feature_flags(duo_code_review_on_agent_platform: false)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
          end

          context 'when user lacks Duo access' do
            let(:has_duo_access) { false }

            it 'does not assign Duo bot as a reviewer and shows access error message' do
              send_request
              expect(response).to redirect_to(project_merge_request_path(project, merge_request))
              follow_redirect!
              expect(flash[:alert]).to include("GitLab Duo Code Review was not automatically added")
              expect(merge_request.reload.reviewers).not_to include(duo_bot)
            end
          end

          context 'when user has Duo access' do
            let(:has_duo_access) { true }

            it 'assigns Duo bot as a reviewer' do
              send_request
              expect(response).to redirect_to(project_merge_request_path(project, merge_request))
              follow_redirect!
              expect(flash[:alert]).to be_nil
              expect(merge_request.reload.reviewers).to include(duo_bot)
            end
          end
        end

        context 'with DAP flow (duo_code_review_on_agent_platform enabled)' do
          let(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
          let(:has_duo_access) { true }

          before do
            stub_ee_application_setting(instance_level_ai_beta_features_enabled: true)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)

            allow_next_instance_of(MergeRequest) do |instance|
              allow(instance).to receive(:ai_review_merge_request_allowed?).with(user).and_return(true)
            end
          end

          it 'assigns Duo bot as a reviewer' do
            send_request
            expect(response).to redirect_to(project_merge_request_path(project, merge_request))
            follow_redirect!
            expect(flash[:alert]).to be_nil
            expect(merge_request.reload.reviewers).to include(duo_bot)
          end
        end

        context 'with Duo Enterprise add-on and DAP enabled' do
          let(:has_duo_access) { true }

          before do
            stub_feature_flags(duo_code_review_on_agent_platform: true)
            stub_feature_flags(duo_code_review_dap_internal_users: true)
            stub_ee_application_setting(instance_level_ai_beta_features_enabled: false)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)

            allow_next_instance_of(MergeRequest) do |instance|
              allow(instance).to receive(:ai_review_merge_request_allowed?).with(user).and_return(true)
            end
          end

          it 'still assigns Duo bot because Duo Enterprise is always available' do
            send_request
            expect(response).to redirect_to(project_merge_request_path(project, merge_request))
            follow_redirect!
            expect(flash[:alert]).to be_nil
            expect(merge_request.reload.reviewers).to include(duo_bot)
          end
        end
      end
    end
  end
end
