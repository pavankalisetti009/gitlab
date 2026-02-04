# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a custom dashboard', :without_current_organization, feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }

  let(:valid_config) do
    {
      version: "2",
      title: "Quarterly Sales Dashboard",
      description: "Revenue performance tracking",
      panels: [
        {
          title: "Total Revenue",
          visualization: "number",
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  let(:variables) do
    {
      organizationId: GitlabSchema.id_from_object(organization).to_s,
      name: "Quarterly Sales",
      description: "Revenue performance KPIs",
      config: valid_config
    }
  end

  let(:mutation) do
    graphql_mutation(
      :create_custom_dashboard,
      variables,
      <<~QL
        dashboard {
          id
          name
          description
          config
          organization {
            id
          }
          createdBy {
            id
          }
        }
        errors
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:create_custom_dashboard) }

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(custom_dashboard_storage: true)
  end

  context 'when user is organization owner' do
    before_all do
      create(:organization_user, :owner, organization: organization, user: user)
    end

    it 'creates a dashboard with valid config' do
      expect do
        user.update!(organization: organization)
        post_graphql_mutation(mutation, current_user: user)
      end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

      dashboard = Analytics::CustomDashboards::Dashboard.last

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']).to include(
        'name' => 'Quarterly Sales',
        'description' => 'Revenue performance KPIs'
      )
      expect(dashboard.organization).to eq(organization)
      expect(dashboard.created_by).to eq(user)
      expect(dashboard.config).to eq(valid_config.deep_stringify_keys)
    end

    context 'when config is invalid' do
      let(:variables) { super().merge(config: { invalid: "schema" }) }

      it 'returns validation errors' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(mutation_response['errors']).to be_present
        expect(mutation_response['dashboard']).to be_nil
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it 'returns an authorization error' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it 'returns an authorization error' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
      end
    end

    context 'when namespace is provided' do
      let_it_be(:namespace) { create(:namespace) }

      before do
        variables[:namespaceId] = GitlabSchema.id_from_object(namespace).to_s
      end

      it 'creates a dashboard scoped to the namespace' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        dashboard = Analytics::CustomDashboards::Dashboard.last

        expect(mutation_response['errors']).to be_empty
        expect(dashboard.namespace).to eq(namespace)
        expect(dashboard.organization).to eq(organization)
      end
    end

    context 'when namespace_id is invalid' do
      before do
        variables[:namespaceId] = "gid://gitlab/Namespace/#{non_existing_record_id}"
      end

      it 'creates dashboard without namespace association' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        dashboard = Analytics::CustomDashboards::Dashboard.last

        expect(mutation_response['errors']).to be_empty
        expect(dashboard.namespace).to be_nil
        expect(dashboard.organization).to eq(organization)
      end
    end
  end

  context 'when user is organization member but not owner' do
    let_it_be(:regular_member) { create(:user) }

    before_all do
      create(:organization_user, organization: organization, user: regular_member)
    end

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: regular_member)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when user is not organization member' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: unauthorized_user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end
end
