# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::RiskScoreResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_risk_score) do
    context = { current_user: user }
    context[:report_type] = report_type_filter if defined?(report_type_filter)
    context[:project_id] = project_id_filter if defined?(project_id_filter)
    resolve(described_class, obj: operate_on, args: {}, ctx: context)
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  describe '#resolve' do
    let(:operate_on) { group }

    before_all do
      group.add_developer(user)
    end

    context 'when feature flag is disabled' do
      before do
        stub_licensed_features(security_dashboard: true)
        stub_feature_flags(new_security_dashboard_total_risk_score: false)
      end

      it 'returns nil' do
        expect(resolved_risk_score).to be_nil
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
        stub_feature_flags(new_security_dashboard_total_risk_score: true)
      end

      it 'returns dummy risk score data' do
        result = resolved_risk_score

        expect(result).to include(
          score: be_a(Float),
          rating: be_in(%w[low medium high critical unknown]),
          factors: include(
            vulnerabilities_average_score: include(factor: be_a(Float))
          ),
          by_project: be_an(Array)
        )
      end

      context 'with project_id filter' do
        let(:project_id_filter) { [project1.id] }

        it 'filters by specific projects' do
          result = resolved_risk_score

          expect(result[:by_project].map { |p| p[:project][:id] }).to contain_exactly(project1.id)
        end
      end
    end
  end
end
