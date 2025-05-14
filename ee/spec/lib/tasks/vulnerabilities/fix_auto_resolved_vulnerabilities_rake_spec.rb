# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vulnerabilities rake tasks', :silence_stdout, feature_category: :vulnerability_management do
  before do
    Rake.application.rake_require 'lib/gitlab/database/migrations/batched_background_migration_helpers'
    Rake.application.rake_require 'tasks/vulnerabilities'
  end

  describe 'fix_auto_resolved_vulnerabilities' do
    let(:namespace_id) { nil }
    let(:instance) { true }
    let(:args) { [namespace_id, instance] }

    subject(:task) { run_rake_task('vulnerabilities:fix_auto_resolved_vulnerabilities', args) }

    it 'schedules migration' do
      expect(batched_migration).to have_scheduled_batched_migration(
        table_name: :vulnerability_reads,
        column_name: :vulnerability_id,
        gitlab_schema: :gitlab_sec,
        job_arguments: [namespace_id, instance]
      )
    end
  end
end
