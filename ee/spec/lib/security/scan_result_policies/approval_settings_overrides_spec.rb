# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalSettingsOverrides, '#all', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:security_configuration) { create(:security_orchestration_policy_configuration) }

  subject(:overrides) do
    described_class
      .new(project: project, security_policies: Security::Policy.all)
      .all
    .map do |override|
      { attribute: override.attribute, policies: override.security_policies.to_a }
    end
  end

  before do
    project.clear_memoization(:merge_requests_author_approval)
    project.clear_memoization(:merge_requests_disable_committers_approval)
  end

  context 'without policies' do
    it { is_expected.to be_empty }
  end

  context 'with restrictive project settings' do
    before do
      project_settings!(
        prevent_approval_by_author: true,
        prevent_approval_by_commit_author: true,
        remove_approvals_with_new_commit: true,
        require_password_to_approve: true)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_commit_author: true) }
    let!(:policy_c) { security_policy(3, remove_approvals_with_new_commit: true) }
    let!(:policy_d) { security_policy(4, require_password_to_approve: true) }

    it { is_expected.to be_empty }
  end

  context 'with restrictive policy approval settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: false,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: [policy_a] }
      ])
    end
  end

  context 'with overlapped restrictive policy approval settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: false,
        require_password_to_approve: false)
    end

    let!(:policy_a) { security_policy(1, prevent_approval_by_author: true) }
    let!(:policy_b) { security_policy(2, prevent_approval_by_author: false) }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: [policy_a] }
      ])
    end
  end

  context 'with mixed settings' do
    before do
      project_settings!(
        prevent_approval_by_author: false,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: true,
        require_password_to_approve: false)
    end

    let!(:policy_1) { security_policy(1, prevent_approval_by_author: true, prevent_approval_by_commit_author: true) }
    let!(:policy_2) { security_policy(2, prevent_approval_by_author: true, remove_approvals_with_new_commit: true) }
    let!(:policy_3) { security_policy(3, prevent_approval_by_commit_author: true, require_password_to_approve: true) }
    let!(:policy_4) { security_policy(4, prevent_approval_by_author: false, require_password_to_approve: true) }
    let!(:policy_5) { security_policy(5, remove_approvals_with_new_commit: false) }

    specify do
      expect(overrides).to match_array([
        { attribute: :prevent_approval_by_author, policies: match_array([policy_1, policy_2]) },
        { attribute: :prevent_approval_by_commit_author, policies: match_array([policy_1, policy_3]) },
        { attribute: :require_password_to_approve, policies: match_array([policy_3, policy_4]) }
      ])
    end
  end

  private

  def project_settings!(approval_settings)
    project.update!(
      approval_settings.to_h do |attr, val|
        case attr
        when :prevent_approval_by_author then [:merge_requests_author_approval, !val]
        when :prevent_approval_by_commit_author then [:merge_requests_disable_committers_approval, val]
        when :remove_approvals_with_new_commit then [:reset_approvals_on_push, val]
        when :require_password_to_approve then [:require_password_to_approve, val]
        else raise
        end
      end
    )
  end

  def security_policy(policy_index, approval_settings)
    create(:security_policy,
      security_orchestration_policy_configuration: security_configuration,
      policy_index: policy_index,
      content: { approval_settings: approval_settings })
  end
end
