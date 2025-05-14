# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vulnerabilities rake tasks', feature_category: :vulnerability_management do
  include RakeHelpers
  include MigrationsHelpers

  before_all do
    Rake.application.rake_require 'ee/lib/tasks/gitlab/vulnerabilities/fix_auto_resolved_vulnerabilities',
      [Rails.root.to_s]
    Rake::Task.define_task(:environment)
  end

  describe 'fix_auto_resolved_vulnerabilities' do
    let(:batched_migration) { 'FixVulnerabilitiesTransitionedFromDismissedToResolved' }

    subject(:task) { run_rake_task('gitlab:vulnerabilities:fix_auto_resolved_vulnerabilities', [namespace_id]) }

    context 'when performing an instance migration' do
      let(:namespace_id) { 'instance' }

      it 'schedules migration' do
        task

        expect(batched_migration).to have_scheduled_batched_migration(
          table_name: :vulnerability_reads,
          column_name: :vulnerability_id,
          gitlab_schema: :gitlab_sec,
          job_arguments: [namespace_id]
        )
      end
    end

    context 'when migrating a namespace' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:namespace_id) { namespace.id.to_s }

      it 'schedules migration with parsed namespace_id' do
        task

        expect(batched_migration).to have_scheduled_batched_migration(
          table_name: :vulnerability_reads,
          column_name: :vulnerability_id,
          gitlab_schema: :gitlab_sec,
          job_arguments: [namespace_id.to_i]
        )
      end
    end
  end
end
