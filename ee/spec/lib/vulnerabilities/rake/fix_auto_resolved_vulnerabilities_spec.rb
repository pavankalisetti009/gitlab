# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Rake::FixAutoResolvedVulnerabilities, feature_category: :vulnerability_management do
  include MigrationsHelpers

  let(:args) { { namespace_id: namespace_id } }

  describe 'execute' do
    let(:batched_migration) { described_class::MIGRATION }

    subject(:execute) { described_class.new(args).execute }

    context 'when performing an instance migration' do
      let(:namespace_id) { 'instance' }

      it 'schedules migration' do
        execute

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
        execute

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
