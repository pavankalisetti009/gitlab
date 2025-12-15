# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::DashboardPolicy, feature_category: :custom_dashboards_foundation do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:dashboard) { create(:dashboard, organization: organization) }

  subject(:policy) { described_class.new(owner, dashboard) }

  before_all do
    create(:organization_user, :owner, organization: organization, user: owner)
  end

  describe 'delegation to organization policy' do
    before do
      stub_licensed_features(product_analytics: true)
      stub_feature_flags(custom_dashboard_storage: true)
    end

    it 'delegates read_custom_dashboard permission to organization' do
      expect(policy.allowed?(:read_custom_dashboard)).to eq(
        Ability.allowed?(owner, :read_custom_dashboard, organization)
      )
    end

    it 'delegates create_custom_dashboard permission to organization' do
      expect(policy.allowed?(:create_custom_dashboard)).to eq(
        Ability.allowed?(owner, :create_custom_dashboard, organization)
      )
    end
  end
end
