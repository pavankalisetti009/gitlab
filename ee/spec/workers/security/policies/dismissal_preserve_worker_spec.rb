# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policies::DismissalPreserveWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_policy) { create(:security_policy) }
  let_it_be(:policy_dismissal) do
    create(:policy_dismissal,
      project: project,
      merge_request: merge_request,
      user: user,
      security_policy: security_policy
    )
  end

  let(:event) do
    Security::PolicyDismissalPreservedEvent.new(
      data: { security_policy_dismissal_id: policy_dismissal.id }
    )
  end

  subject(:worker) { described_class.new }

  describe '#handle_event' do
    context 'when policy dismissal exists' do
      it 'creates an audit event with correct context' do
        expected_audit_context = {
          name: 'merge_request_merged_with_dismissed_security_policy',
          author: user,
          scope: project,
          target: policy_dismissal.security_policy,
          message: "Merge request !#{merge_request.iid} was merged with violated security policy."
        }

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_audit_context)

        worker.handle_event(event)
      end
    end

    context 'when policy dismissal does not exist' do
      let(:event) do
        Security::PolicyDismissalPreservedEvent.new(
          data: { security_policy_dismissal_id: non_existing_record_id }
        )
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        worker.handle_event(event)
      end
    end
  end
end
