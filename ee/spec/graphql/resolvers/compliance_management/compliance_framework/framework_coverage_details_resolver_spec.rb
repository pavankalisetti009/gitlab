# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::ComplianceFramework::FrameworkCoverageDetailsResolver,
  feature_category: :compliance_management do
  include GraphqlHelpers
  include Security::PolicyCspHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }

  before_all do
    group.add_owner(current_user)
    create(:compliance_framework_project_setting, project: project1, compliance_management_framework: framework)
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: group, ctx: { current_user: current_user }) }

    it 'returns framework coverage details' do
      expect(result.items.map(&:framework)).to contain_exactly(framework)
      expect(result.items.first.covered_count).to eq(1)
    end

    context 'when CSP frameworks are configured' do
      let_it_be(:csp_group) { create(:group, organization: group.organization) }
      let_it_be(:csp_framework) { create(:compliance_framework, namespace: csp_group, name: 'CSP Framework') }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        group.clear_memoization(:organization_policy_setting)
        policy_setting = Security::PolicySetting.new(csp_namespace_id: csp_group.id, csp_namespace: csp_group)
        allow(Security::PolicySetting)
          .to receive(:in_organization).with(an_instance_of(Organizations::Organization))
                                        .and_return(policy_setting)
        create(:compliance_framework_project_setting, project: project2, compliance_management_framework: csp_framework)
      end

      it 'includes CSP frameworks in coverage details' do
        frameworks = result.items.map(&:framework)
        expect(frameworks).to include(framework, csp_framework)
      end

      it 'returns correct coverage counts for CSP frameworks' do
        csp_framework_detail = result.items.find { |detail| detail.framework == csp_framework }
        expect(csp_framework_detail.covered_count).to eq(1)
      end

      it 'returns correct coverage counts for regular frameworks' do
        regular_framework_detail = result.items.find { |detail| detail.framework == framework }
        expect(regular_framework_detail.covered_count).to eq(1)
      end
    end

    context 'when group has no projects' do
      let_it_be(:empty_group) { create(:group) }

      before_all do
        empty_group.add_owner(current_user)
      end

      subject(:result) { resolve(described_class, obj: empty_group, ctx: { current_user: current_user }) }

      it 'returns empty array' do
        expect(result.items).to eq([])
      end
    end
  end
end
