# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AllPoliciesFinder, feature_category: :security_policy_management do
  include_context 'with security policies information'

  %i[pipeline_execution_schedule_policy scan_execution_policy pipeline_execution_policy approval_policy
    vulnerability_management_policy].each do |policy_type|
    context "with policy type #{policy_type}" do
      let(:policy) do
        build(policy_type, name: 'My policy', policy_scope: policy_scope)
      end

      let(:policy_yaml) do
        build(:orchestration_policy_yaml, policy_type => [policy])
      end

      it_behaves_like 'security policies finder' do
        let(:expected_extra_attrs) { { type: policy_type.to_s } }

        context 'when feature flag "security_policies_combined_list" is disabled' do
          before do
            stub_licensed_features(security_orchestration_policies: true)
            stub_feature_flags(security_policies_combined_list: false)
            object.add_developer(actor)
          end

          it 'returns empty collection' do
            is_expected.to be_empty
          end
        end
      end
    end
  end
end
