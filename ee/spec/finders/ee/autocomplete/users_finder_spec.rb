# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Autocomplete::UsersFinder, feature_category: :code_review_workflow do
  include Ai::Catalog::FlowFactoryHelpers

  describe '#execute' do
    let(:current_user) { create(:user) }
    let(:params) { {} }

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:users) do
      described_class.new(params: params, current_user: current_user, project: project, group: nil).execute.to_a
    end

    before_all do
      stub_feature_flags(remove_duo_flow_service_accounts_from_autocomplete_query: false)
    end

    describe '#project_users' do
      context 'when project does not have access to Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
        end

        it { is_expected.not_to include(::Users::Internal.duo_code_review_bot) }
      end

      context 'when project has access Duo Code review' do
        before do
          allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
        end

        it { is_expected.to include(::Users::Internal.duo_code_review_bot) }
      end

      context 'when remove_duo_flow_service_accounts_from_autocomplete_query is enabled' do
        let_it_be(:regular_human_account) do
          create(:user, developer_of: project, username: 'regular_human_account')
        end

        let_it_be(:service_account_without_flow) do
          create(:composite_identity_service_account_for_project, project: project, username: 'without_flow')
        end

        let_it_be(:service_account_without_trigger) do
          create(:composite_identity_service_account_for_project, project: project, username: 'without_trigger')
        end

        let_it_be(:service_account_with_mention_trigger) do
          create(:composite_identity_service_account_for_project, project: project, username: 'with_mention_trigger')
        end

        let_it_be(:service_account_with_assign_reviewer_trigger) do
          create(
            :composite_identity_service_account_for_project,
            project: project,
            username: 'with_assign_reviewer_trigger'
          )
        end

        let_it_be(:service_account_with_mention_and_assign_reviewer_trigger) do
          create(
            :composite_identity_service_account_for_project,
            project: project,
            username: 'with_mention_and_assign_reviewer_trigger'
          )
        end

        let_it_be(:service_account_with_assign_and_assign_reviewer_trigger) do
          create(
            :composite_identity_service_account_for_project,
            project: project,
            username: 'with_assign_and_assign_reviewer_trigger'
          )
        end

        let_it_be(:service_account_with_assign_and_mention_trigger) do
          create(
            :composite_identity_service_account_for_project,
            project: project,
            username: 'with_assign_and_mention_trigger'
          )
        end

        before_all do
          stub_feature_flags(remove_duo_flow_service_accounts_from_autocomplete_query: true)

          create_flow_configuration_for_project(
            project, service_account_without_trigger, []
          )
          create_flow_configuration_for_project(
            project, service_account_with_mention_trigger, [0]
          )
          create_flow_configuration_for_project(
            project, service_account_with_assign_reviewer_trigger, [2]
          )
          create_flow_configuration_for_project(
            project, service_account_with_mention_and_assign_reviewer_trigger, [0, 2]
          )
          create_flow_configuration_for_project(
            project, service_account_with_assign_and_assign_reviewer_trigger, [1, 2]
          )
          create_flow_configuration_for_project(
            project, service_account_with_assign_and_mention_trigger, [0, 1]
          )
        end

        context 'when not filtering for any trigger events' do
          let(:params) do
            {
              include_service_accounts_for_trigger_events: nil
            }
          end

          it 'does not exclude flow service accounts' do
            expect(users)
              .to include(
                regular_human_account,
                service_account_without_flow,
                service_account_without_trigger,
                service_account_with_mention_trigger,
                service_account_with_assign_and_mention_trigger,
                service_account_with_assign_reviewer_trigger,
                service_account_with_mention_and_assign_reviewer_trigger,
                service_account_with_assign_and_assign_reviewer_trigger
              )
          end
        end

        context 'when including no trigger events' do
          let(:params) do
            {
              include_service_accounts_for_trigger_events: []
            }
          end

          it 'excludes all flow service accounts' do
            expect(users)
              .to include(
                regular_human_account,
                service_account_without_flow
              )
              .and not_include(
                service_account_without_trigger,
                service_account_with_mention_trigger,
                service_account_with_assign_and_mention_trigger,
                service_account_with_assign_reviewer_trigger,
                service_account_with_mention_and_assign_reviewer_trigger,
                service_account_with_assign_and_assign_reviewer_trigger
              )
          end
        end

        context 'when including single trigger event' do
          let(:params) do
            {
              include_service_accounts_for_trigger_events: [2]
            }
          end

          it 'excludes flow service accounts with no triggers and includes those with that event type' do
            expect(users)
              .to include(
                regular_human_account,
                service_account_without_flow,
                service_account_with_assign_reviewer_trigger,
                service_account_with_mention_and_assign_reviewer_trigger,
                service_account_with_assign_and_assign_reviewer_trigger
              )
              .and not_include(
                service_account_without_trigger,
                service_account_with_mention_trigger,
                service_account_with_assign_and_mention_trigger
              )
          end
        end

        context 'when including multiple trigger events' do
          let(:params) do
            {
              include_service_accounts_for_trigger_events: [0, 1]
            }
          end

          it 'excludes flow service accounts with no triggers and includes those with those event types' do
            expect(users)
              .to include(
                regular_human_account,
                service_account_without_flow,
                service_account_with_mention_trigger,
                service_account_with_assign_and_mention_trigger,
                service_account_with_mention_and_assign_reviewer_trigger,
                service_account_with_assign_and_assign_reviewer_trigger
              )
                .and not_include(
                  service_account_without_trigger,
                  service_account_with_assign_reviewer_trigger
                )
          end
        end
      end
    end
  end
end
