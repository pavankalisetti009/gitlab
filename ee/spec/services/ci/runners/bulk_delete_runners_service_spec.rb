# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::BulkDeleteRunnersService, '#execute', feature_category: :fleet_visibility do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:audit_service) { instance_double(::AuditEvents::BulkDeleteRunnersAuditEventService) }
  let(:current_user) { create(:admin) }

  subject(:execute) { described_class.new(runners: runners, current_user: current_user).execute }

  shared_examples 'a service that logs an audit event' do
    let!(:expected_runners) { runners.to_a }

    it 'logs an audit event with the scope of the current user' do
      expect(audit_service).to receive(:track_event).once.and_return('track_event_return_value')
      expect(::AuditEvents::BulkDeleteRunnersAuditEventService).to receive(:new)
        .with(expected_runners, current_user)
        .once.and_return(audit_service)

      execute
    end
  end

  context 'when user is allowed to delete runners', :enable_admin_mode do
    context 'on an instance runner' do
      let!(:instance_runners) { create_list(:ci_runner, 3) }
      let(:runners) { Ci::Runner.id_in(instance_runners.map(&:id).take(2)) }

      it_behaves_like 'a service that logs an audit event'
    end

    context 'on a group runner' do
      let!(:group_runners) { create_list(:ci_runner, 2, :group, groups: [group]) }
      let(:runners) { Ci::Runner.group_type }

      it_behaves_like 'a service that logs an audit event'
    end

    context 'on a project runner' do
      let!(:project_runners) { create_list(:ci_runner, 2, :project, projects: [project]) }
      let(:runners) { Ci::Runner.project_type }

      it_behaves_like 'a service that logs an audit event'
    end
  end
end
