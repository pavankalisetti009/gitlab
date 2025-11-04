# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventService, '#execute', feature_category: :security_policy_management do
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

  let_it_be_with_reload(:project) do
    create(:project, merge_requests_author_approval: true, merge_requests_disable_committers_approval: false,
      require_password_to_approve: false)
  end

  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:warn_mode_policy_a) do
    create_policy(name: "A", policy_index: 1, warn_mode: true, approval_settings: { prevent_approval_by_author: true })
  end

  let_it_be(:warn_mode_policy_b) do
    create_policy(name: "B", policy_index: 2, warn_mode: true,
      approval_settings: { prevent_approval_by_commit_author: true })
  end

  let_it_be(:warn_mode_policy_c) do
    create_policy(name: "C", policy_index: 3, warn_mode: true, approval_settings: { require_password_to_approve: true })
  end

  let_it_be(:enforced_policy_a) do
    create_policy(name: "D", policy_index: 4, approval_settings: { prevent_approval_by_author: true })
  end

  let_it_be(:enforced_policy_b) do
    create_policy(name: "E", policy_index: 5, approval_settings: { prevent_approval_by_commit_author: true })
  end

  let_it_be(:enforced_policy_c) do
    create_policy(name: "F", policy_index: 6, approval_settings: { require_password_to_approve: true })
  end

  let(:warn_mode_policies) { [] }
  let(:enforced_policies) { [] }
  let(:committers) { [project.creator] }
  let(:commit_collection) { instance_double(CommitCollection, committers: committers) }
  let(:service) { described_class.new(merge_request, user) }

  subject(:execute) { Gitlab::SafeRequestStore.ensure_request_store { service.execute } }

  before do
    [*warn_mode_policies, *enforced_policies].each do |policy|
      create(:security_policy_project_link, project: project, security_policy: policy)
    end

    allow(merge_request).to receive(:commits).and_return(commit_collection)
  end

  shared_examples 'does not create audit events' do
    specify do
      expect { execute }.not_to change { AuditEvent.count }.from(0)
    end
  end

  shared_examples 'creates audit events' do |expected_attributes|
    specify do
      expected_array_members = expected_attributes.map do |attrs|
        hash_including(
          attrs.merge(
            event_name: described_class::AUDIT_EVENT,
            author_name: 'GitLab Security Policy Bot',
            author_class: 'User',
            target_type: 'MergeRequest',
            target_id: merge_request.id))
      end

      expect { execute }.to change { AuditEvent.all.pluck(:details) }
                              .from(be_empty)
                              .to(match_array(expected_array_members))
    end
  end

  context 'with restrictive warn-mode policy' do
    describe 'prevent_approval_by_author' do
      let(:warn_mode_policies) { [warn_mode_policy_a] }

      context 'when approver is not author' do
        include_examples 'does not create audit events'
      end

      context 'when approver is author' do
        let(:user) { merge_request.author }

        include_examples 'creates audit events', [{
          custom_message: "The merge request author approved their own merge request, " \
            "which would have been prevented by the following security policies in warn mode: A"
        }]

        context 'with enforced policy' do
          let(:enforced_policies) { [enforced_policy_a] }

          include_examples 'does not create audit events'
        end
      end
    end

    describe 'prevent_approval_by_commit_author' do
      let(:warn_mode_policies) { [warn_mode_policy_b] }

      context 'when approver has not committed' do
        include_examples 'does not create audit events'
      end

      context 'when approver has committed' do
        let(:committers) { [user] }

        include_examples 'creates audit events', [{
          custom_message: "A user approved a merge request that they also committed to, " \
            "which would have been prevented by the following security policies in warn mode: B"
        }]

        context 'with enforced policy' do
          let(:enforced_policies) { [enforced_policy_b] }

          include_examples 'does not create audit events'
        end
      end
    end

    describe 'require_password_to_approve' do
      let(:warn_mode_policies) { [warn_mode_policy_c] }

      context 'when project requires password approval' do
        before do
          project.update!(require_password_to_approve: true)
        end

        include_examples 'does not create audit events'
      end

      context 'when project does not require password approval' do
        include_examples 'creates audit events', [{
          custom_message: "A user approved a merge request without reauthenticating, " \
            "which would have been prevented by the following security policies in warn mode: C"
        }]

        context 'with enforced policy' do
          let(:enforced_policies) { [enforced_policy_c] }

          include_examples 'does not create audit events'
        end
      end
    end
  end

  context 'with multiple restrictive policies' do
    let_it_be(:warn_mode_policy_g) do
      create_policy(name: "G", policy_index: 7, warn_mode: true,
        approval_settings: { prevent_approval_by_author: true })
    end

    let_it_be(:warn_mode_policy_h) do
      create_policy(name: "H", policy_index: 8, warn_mode: true,
        approval_settings: { prevent_approval_by_author: true, prevent_approval_by_commit_author: true })
    end

    let(:user) { merge_request.author }
    let(:committers) { [user] }
    let(:enforced_policies) { [warn_mode_policy_g, warn_mode_policy_h] }

    include_examples 'creates audit events', [
      {
        custom_message: "A user approved a merge request that they also committed to, " \
          "which would have been prevented by the following security policies in warn mode: H"
      },
      {
        custom_message: "The merge request author approved their own merge request, " \
          "which would have been prevented by the following security policies in warn mode: G, H"
      }
    ]
  end

  private

  def create_policy(name:, policy_index:, approval_settings: {}, enabled: true, warn_mode: false)
    build(:security_policy,
      security_orchestration_policy_configuration: policy_configuration,
      enabled: enabled,
      policy_index: policy_index
    ).tap do |policy|
      content = policy
                  .content
                  .merge("approval_settings" => approval_settings,
                    "enforcement_type" => if warn_mode
                                            Security::Policy::ENFORCEMENT_TYPE_WARN
                                          else
                                            Security::Policy::DEFAULT_ENFORCEMENT_TYPE
                                          end)

      policy.update!(name: name, content: content)
    end
  end
end
