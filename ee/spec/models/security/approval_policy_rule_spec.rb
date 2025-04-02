# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyRule, feature_category: :security_policy_management do
  it_behaves_like 'policy rule' do
    let(:rule_hash) { build(:scan_result_policy)[:rules].first }
    let(:policy_type) { :approval_policy }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:security_policy) }
    it { is_expected.to have_one(:approval_project_rule) }
    it { is_expected.to have_many(:approval_merge_request_rules) }
    it { is_expected.to have_many(:violations) }
    it { is_expected.to have_many(:approval_policy_rule_project_links) }
    it { is_expected.to have_many(:projects).through(:approval_policy_rule_project_links) }
  end

  describe 'validations' do
    describe 'content' do
      subject(:rule) { build(:approval_policy_rule, trait) }

      context 'when scan_finding' do
        let(:trait) { :scan_finding }

        it { is_expected.to be_valid }
      end

      context 'when license_finding' do
        let(:trait) { :license_finding }

        it { is_expected.to be_valid }
      end

      context 'when any_merge_request' do
        let(:trait) { :any_merge_request }

        it { is_expected.to be_valid }
      end

      context 'when license_finding_with_allowed_licenses' do
        let(:trait) { :license_finding_with_allowed_licenses }

        it { is_expected.to be_valid }
      end

      context 'when license_finding_with_denied_licenses' do
        let(:trait) { :license_finding_with_denied_licenses }

        it { is_expected.to be_valid }
      end

      context 'when license_finding defines the license list using both the current and new set of keys' do
        let(:trait) { :license_finding_with_current_and_new_keys }

        it { is_expected.not_to be_valid }
      end
    end
  end

  describe '.by_policy_rule_index' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, security_policy: security_policy, rule_index: 2)
    end

    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, rule_index: 3) }

    it 'returns the correct approval policy rule' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 1, rule_index: 2)

      expect(result).to eq(approval_policy_rule)
    end

    it 'does not return approval policy rules with different policy configuration' do
      other_policy_configuration = create(:security_orchestration_policy_configuration)
      result = described_class.by_policy_rule_index(other_policy_configuration, policy_index: 1, rule_index: 2)

      expect(result).to be_nil
    end

    it 'does not return approval policy rules with different policy index' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 2, rule_index: 2)

      expect(result).to be_nil
    end

    it 'does not return approval policy rules with different rule index' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 1, rule_index: 3)

      expect(result).to be_nil
    end

    it 'returns an empty relation when no matching rules are found' do
      result = described_class.by_policy_rule_index(policy_configuration, policy_index: 99, rule_index: 99)

      expect(result).to be_nil
    end
  end

  describe '.deleted' do
    let_it_be(:rule_with_positive_index) { create(:approval_policy_rule, rule_index: 1) }
    let_it_be(:rule_with_zero_index) { create(:approval_policy_rule, rule_index: 0) }
    let_it_be(:rule_with_negative_index) { create(:approval_policy_rule, rule_index: -1) }

    it 'returns rules with rule_index lesser than 0' do
      result = described_class.deleted

      expect(result).to contain_exactly(rule_with_negative_index)
      expect(result).not_to include(rule_with_positive_index, rule_with_zero_index)
    end
  end

  describe '.undeleted' do
    let_it_be(:rule_with_positive_index) { create(:approval_policy_rule, rule_index: 1) }
    let_it_be(:rule_with_zero_index) { create(:approval_policy_rule, rule_index: 0) }
    let_it_be(:rule_with_negative_index) { create(:approval_policy_rule, rule_index: -1) }

    it 'returns rules with rule_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(rule_with_positive_index, rule_with_zero_index)
      expect(result).not_to include(rule_with_negative_index)
    end
  end

  describe '.licenses' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:licenses) { rule.licenses }

    context 'when typed_content does not contain licenses information' do
      it 'returns nil' do
        expect(licenses).to be_nil
      end
    end

    context 'when typed_content contain licenses information' do
      let_it_be(:allowed_licenses) do
        { "allowed" => [{ "name" => "MIT License",
                          "packages" => { "excluding" => { "purls" => ["pkg:gem/bundler@1.0.0"] } } }] }
      end

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding_with_allowed_licenses) }

      it 'returns the list of licenses' do
        expect(licenses).to eq(allowed_licenses)
      end
    end
  end

  describe '.license_states' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:license_states) { rule.license_states }

    context 'when typed_content does not contain license_states information' do
      it 'returns nil' do
        expect(license_states).to be_nil
      end
    end

    context 'when typed_content contain license_states information' do
      let_it_be(:expected_license_states) { %w[newly_detected detected] }

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding_with_allowed_licenses) }

      it 'returns the list of licenses' do
        expect(license_states).to eq(expected_license_states)
      end
    end
  end

  describe '.license_types' do
    let_it_be(:rule) { build(:approval_policy_rule, :any_merge_request) }

    subject(:license_types) { rule.license_types }

    context 'when typed_content does not contain license_types information' do
      it 'returns nil' do
        expect(license_types).to be_nil
      end
    end

    context 'when typed_content contain license_states information' do
      let_it_be(:expected_license_types) { %w[BSD MIT] }

      let_it_be(:rule) { build(:approval_policy_rule, :license_finding) }

      it 'returns the list of licenses' do
        expect(license_types).to eq(expected_license_types)
      end
    end
  end
end
