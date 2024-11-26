# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSeatAssignmentsTable, feature_category: :seat_cost_management do
  let!(:users) { table(:users) }
  let!(:namespaces) { table(:namespaces) }
  let!(:projects) { table(:projects) }
  let!(:members) { table(:members) }

  let!(:subscription_seat_assignments) { table(:subscription_seat_assignments) }

  let!(:user) { users.create!(name: 'test-1', email: 'test@example.com', projects_limit: 5) }
  let!(:other_user) { users.create!(name: 'test-2', email: 'test-2@example.com', projects_limit: 5) }

  let!(:root_group) do
    namespaces.create!(name: 'root-group', path: 'root-group', type: 'Group').tap do |new_group|
      new_group.update!(traversal_ids: [new_group.id])
    end
  end

  let!(:sub_group) do
    namespaces.create!(name: 'subgroup', path: 'subgroup', parent_id: root_group.id, type: 'Group').tap do |new_group|
      new_group.update!(traversal_ids: [root_group.id, new_group.id])
    end
  end

  let!(:other_root_group) do
    namespaces.create!(name: 'other root group', path: 'other-root-group', type: 'Group').tap do |new_group|
      new_group.update!(traversal_ids: [new_group.id])
    end
  end

  let!(:project) do
    projects.create!(
      namespace_id: root_group.id,
      project_namespace_id: root_group.id,
      name: 'group project',
      path: 'group-project'
    )
  end

  let!(:project_sub) do
    projects.create!(
      namespace_id: sub_group.id, project_namespace_id: sub_group.id, name: 'subgroup project', path: 'subgroup-project'
    )
  end

  let!(:project_other) do
    projects.create!(
      namespace_id: other_root_group.id,
      project_namespace_id: other_root_group.id,
      name: 'other group project',
      path: 'other-group-project'
    )
  end

  let(:migration_args) do
    {
      start_id: members.minimum(:id),
      end_id: members.maximum(:id),
      batch_table: :members,
      batch_column: :id,
      sub_batch_size: sub_batch_size,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  subject(:migration) { described_class.new(**migration_args) }

  describe '#perform' do
    let(:sub_batch_size) { 3 }

    before do
      members.create!(
        access_level: 50,
        source_id: project.id,
        source_type: "Project",
        user_id: user.id,
        state: 0,
        notification_level: 3,
        type: "ProjectMember",
        member_namespace_id: project.project_namespace_id
      )
      members.create!(
        access_level: 50,
        source_id: project_sub.id,
        source_type: "Project",
        user_id: other_user.id,
        state: 0,
        notification_level: 3,
        type: "ProjectMember",
        member_namespace_id: project_sub.project_namespace_id
      )

      members.create!(
        access_level: 50,
        source_id: other_root_group.id,
        source_type: "Group",
        user_id: other_user.id,
        state: 0,
        notification_level: 3,
        type: "GroupMember",
        member_namespace_id: other_root_group.id
      )
      members.create!(
        access_level: 50,
        source_id: project_other.id,
        source_type: "Project",
        user_id: user.id,
        state: 0,
        notification_level: 3,
        type: "ProjectMember",
        member_namespace_id: project_other.project_namespace_id
      )
    end

    it 'backfills the seat assignment table per root namespace per user' do
      expect(subscription_seat_assignments.count).to eq(0)

      migration.perform

      expect(subscription_seat_assignments.count).to eq(4)

      expect(subscription_seat_assignments.where(namespace_id: root_group.id, user_id: user.id).count).to eq(1)
      expect(subscription_seat_assignments.where(namespace_id: root_group.id, user_id: other_user.id).count).to eq(1)
      expect(subscription_seat_assignments.where(namespace_id: other_root_group.id, user_id: other_user.id).count)
        .to eq(1)
      expect(subscription_seat_assignments.where(namespace_id: other_root_group.id, user_id: user.id).count).to eq(1)
    end

    context 'when user has multiple membership in the hierarchy' do
      before do
        members.create!(
          access_level: 50,
          source_id: root_group.id,
          source_type: "Group",
          user_id: user.id,
          state: 0,
          notification_level: 3,
          type: "GroupMember",
          member_namespace_id: root_group.id
        )
        members.create!(
          access_level: 50,
          source_id: root_group.id,
          source_type: "Group",
          user_id: other_user.id,
          state: 0,
          notification_level: 3,
          type: "GroupMember",
          member_namespace_id: root_group.id
        )

        members.create!(
          access_level: 50,
          source_id: other_root_group.id,
          source_type: "Group",
          user_id: user.id,
          state: 0,
          notification_level: 3,
          type: "GroupMember",
          member_namespace_id: other_root_group.id
        )
        members.create!(
          access_level: 50,
          source_id: project_other.id,
          source_type: "Project",
          user_id: other_user.id,
          state: 0,
          notification_level: 3,
          type: "ProjectMember",
          member_namespace_id: project_other.project_namespace_id
        )
      end

      it 'creates only one record per root namespace and user' do
        migration.perform

        expect(subscription_seat_assignments.count).to eq(4)

        expect(subscription_seat_assignments.where(namespace_id: root_group.id, user_id: user.id).count).to eq(1)
        expect(subscription_seat_assignments.where(namespace_id: root_group.id, user_id: other_user.id).count).to eq(1)
        expect(subscription_seat_assignments.where(namespace_id: other_root_group.id, user_id: other_user.id).count)
          .to eq(1)
        expect(subscription_seat_assignments.where(namespace_id: other_root_group.id, user_id: user.id).count).to eq(1)
      end
    end

    context 'when member has user_id NULL' do
      before do
        members.create!(
          access_level: 50,
          source_id: project_sub.id,
          source_type: 'Project',
          user_id: nil,
          state: 0,
          notification_level: 3,
          type: 'ProjectMember',
          member_namespace_id: project_sub.project_namespace_id
        )
      end

      it 'handles and skips the null values correctly' do
        migration.perform

        expect(subscription_seat_assignments.count).to eq(4)
      end
    end

    context 'when record already exists on subscription_seat_assignments table' do
      let(:sub_batch_size) { 1 }

      before do
        subscription_seat_assignments.create!(namespace_id: root_group.id, user_id: user.id)
        subscription_seat_assignments.create!(namespace_id: root_group.id, user_id: other_user.id)
        subscription_seat_assignments.create!(namespace_id: other_root_group.id, user_id: other_user.id)
      end

      it 'does not call insert for existing records' do
        expect(subscription_seat_assignments.count).to eq(3)

        expected_attributes = [
          a_hash_including({ namespace_id: other_root_group.id, user_id: user.id })
        ]

        expect(described_class::MigrationSeatAssignmentTable)
          .to receive(:insert_all)
          .once
          .with(expected_attributes, kind_of(Hash))
          .and_call_original

        migration.perform

        expect(subscription_seat_assignments.count).to eq(4)
      end
    end
  end
end
