# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'autocomplete users for a project', feature_category: :team_planning do
  include GraphqlHelpers
  include Ai::Catalog::FlowFactoryHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, :public, group: group) }
  let_it_be(:direct_member) { create(:user, guest_of: project) }

  let(:params) { {} }
  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('autocompleteUsers', params, 'id username')
    )
  end

  describe 'include_service_accounts_for_trigger_events' do
    let(:users) { graphql_data.dig('project', 'autocompleteUsers').pluck('username') }

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

    let_it_be(:service_account_with_assign_trigger) do
      create(:composite_identity_service_account_for_project, project: project, username: 'with_assign_trigger')
    end

    before do
      create_flow_configuration_for_project(
        project, service_account_without_trigger, []
      )
      create_flow_configuration_for_project(
        project, service_account_with_mention_trigger, [0]
      )
      create_flow_configuration_for_project(
        project, service_account_with_assign_trigger, [1]
      )
    end

    context 'when include_service_accounts_for_trigger_events is not empty' do
      let(:params) { { include_service_accounts_for_trigger_events: [:ASSIGN] } }

      context 'and remove_duo_flow_service_accounts_from_autocomplete_query is disabled' do
        before do
          stub_feature_flags(remove_duo_flow_service_accounts_from_autocomplete_query: false)
        end

        it 'does not exclude any Duo service accounts' do
          post_graphql(query, current_user: direct_member)

          expect(users)
            .to include(
              regular_human_account.username,
              service_account_without_flow.username,
              service_account_with_assign_trigger.username,
              service_account_without_trigger.username,
              service_account_with_mention_trigger.username
            )
        end
      end

      context 'and remove_duo_flow_service_accounts_from_autocomplete_query is enabled' do
        it 'excludes service accounts without the selected trigger event' do
          post_graphql(query, current_user: direct_member)

          expect(users)
            .to include(
              regular_human_account.username,
              service_account_without_flow.username,
              service_account_with_assign_trigger.username
            ).and exclude(
              service_account_without_trigger.username,
              service_account_with_mention_trigger.username
            )
        end
      end
    end

    context 'when include_service_accounts_for_trigger_events is empty' do
      context 'and remove_duo_flow_service_accounts_from_autocomplete_query is enabled' do
        it 'does not exclude any Duo service accounts' do
          post_graphql(query, current_user: direct_member)

          expect(users)
              .to include(
                regular_human_account.username,
                service_account_without_flow.username,
                service_account_with_assign_trigger.username,
                service_account_without_trigger.username,
                service_account_with_mention_trigger.username
              )
        end
      end
    end
  end
end
