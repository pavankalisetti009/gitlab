# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateWarnModeAuditEventsWorker, feature_category: :security_policy_management do
  include_context 'with policy sync state'

  let_it_be(:group) { create(:group) }

  let_it_be(:project_a) { create(:project, group: group) }
  let_it_be(:project_b) { create(:project, group: group) }

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: group)
  end

  let_it_be(:warn_mode_policy_enabled) do
    create(:security_policy, :warn_mode, enabled: true,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
  end

  let_it_be(:warn_mode_policy_disabled) do
    create(:security_policy, :warn_mode, enabled: false,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 2)
  end

  let_it_be(:enforced_policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 3)
  end

  subject(:handle_event) { described_class.new.handle_event(event) }

  before do
    stub_csp_group(nil)
  end

  shared_examples 'enqueues workers' do
    specify do
      expect(Security::ScanResultPolicies::CreateProjectWarnModeAuditEventsWorker).to \
        receive(:bulk_perform_async_with_contexts)
           .with(
             contain_exactly(project_a.id,
               project_b.id),
             hash_including(
               arguments_proc: an_instance_of(Proc),
               context_proc: an_instance_of(Proc)
             )
           ) do |_project_ids, options|
        expect(options[:arguments_proc].call(project_a.id)).to contain_exactly(project_a.id, policy.id)
        expect(options[:context_proc].call(nil)).to eq(namespace: group)
      end

      handle_event
    end
  end

  shared_examples 'does not enqueue workers' do
    specify do
      expect(Security::ScanResultPolicies::CreateProjectWarnModeAuditEventsWorker)
        .not_to receive(:bulk_perform_async_with_contexts)

      handle_event
    end
  end

  context 'on create' do
    let(:event) { Security::PolicyCreatedEvent.new(data: { security_policy_id: policy.id }) }

    it_behaves_like 'subscribes to event' do
      let(:policy) { warn_mode_policy_enabled }
    end

    context 'with warn-mode policy' do
      context 'when enabled' do
        let(:policy) { warn_mode_policy_enabled }

        it_behaves_like 'enqueues workers'
      end

      context 'when disabled' do
        let(:policy) { warn_mode_policy_disabled }

        it_behaves_like 'does not enqueue workers'
      end
    end

    context 'with enforced policy' do
      let(:policy) { enforced_policy }

      it_behaves_like 'does not enqueue workers'
    end
  end

  context 'on update' do
    let(:event) do
      Security::PolicyUpdatedEvent.new(
        data: { security_policy_id: policy.id,
                diff: ActiveSupport::HashWithIndifferentAccess.new(diff),
                rules_diff: { created: [], updated: [], deleted: [] } })
    end

    it_behaves_like 'subscribes to event' do
      let(:diff) { {} }
      let(:policy) { warn_mode_policy_enabled }
    end

    context 'with updated approval settings' do
      let(:diff) do
        { "approval_settings" => {
          "from" => { "prevent_approval_by_commit_author" => false },
          "to" => { "prevent_approval_by_commit_author" => true }
        } }
      end

      context 'with warn-mode policy' do
        context 'when enabled' do
          let(:policy) { warn_mode_policy_enabled }

          it_behaves_like 'enqueues workers'
        end

        context 'when disabled' do
          let(:policy) { warn_mode_policy_disabled }

          it_behaves_like 'does not enqueue workers'
        end
      end

      context 'with enforced policy' do
        let(:policy) { enforced_policy }

        it_behaves_like 'does not enqueue workers'
      end
    end

    context 'with unchanged approval settings' do
      let(:diff) { {} }

      context 'with warn-mode policy' do
        context 'when enabled' do
          let(:policy) { warn_mode_policy_enabled }

          it_behaves_like 'does not enqueue workers'
        end

        context 'when disabled' do
          let(:policy) { warn_mode_policy_disabled }

          it_behaves_like 'does not enqueue workers'
        end
      end

      context 'with enforced policy' do
        let(:policy) { enforced_policy }

        it_behaves_like 'does not enqueue workers'
      end
    end
  end

  context 'with project-level configuration' do
    let_it_be(:project_level_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project_a)
    end

    let_it_be(:warn_mode_policy) do
      create(:security_policy, :warn_mode,
        security_orchestration_policy_configuration: project_level_policy_configuration, policy_index: 1)
    end

    let(:event) { Security::PolicyCreatedEvent.new(data: { security_policy_id: warn_mode_policy.id }) }

    it 'enqueues worker' do
      expect(Security::ScanResultPolicies::CreateProjectWarnModeAuditEventsWorker).to \
        receive(:bulk_perform_async_with_contexts)
           .with(
             contain_exactly(project_a.id),
             hash_including(
               arguments_proc: an_instance_of(Proc),
               context_proc: an_instance_of(Proc)
             )
           ) do |_project_ids, options|
        expect(options[:arguments_proc].call(project_a.id)).to contain_exactly(project_a.id, warn_mode_policy.id)
        expect(options[:context_proc].call(nil)).to eq(project: project_a)
      end

      handle_event
    end
  end

  context 'with unrecognized event' do
    let(:event) { Struct.new(:data).new(data: { security_policy_id: warn_mode_policy_enabled }) }

    specify do
      expect { handle_event }.to raise_error(RuntimeError)
    end
  end
end
