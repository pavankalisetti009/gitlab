# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::AccessBranchBuilder, feature_category: :global_search do
  subject(:builder) { described_class.new(current_user, auth, options) }

  let(:current_user) { create(:user) }
  let(:auth) { instance_double(::Search::AuthorizationContext) }
  let(:options) do
    {
      group_id: 1,
      project_id: [],
      search_level: :group,
      features: 'repository'
    }
  end

  before do
    allow(auth).to receive(:get_access_levels_for_feature).with('repository')
      .and_return({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })
    allow(auth).to receive_messages(
      get_projects_for_user: Project.none,
      get_groups_for_user: Group.none,
      get_formatted_traversal_ids_for_groups: [],
      get_groups_with_custom_roles: Group.none,
      get_projects_with_custom_roles: Project.none
    )
  end

  describe '#build' do
    context 'when current_user can read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'returns admin branch only' do
        result = builder.build

        expect(result.first.dig(:meta, :key)).to eq('repository_access_level')
        expect(result.first.dig(:meta, :value)).to eq('20|10')
        expect(result.first.dig(:_context, :name)).to eq('admin_branch')
      end
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'returns public branch only' do
        result = builder.build

        expect(result.first).to include(:and)
        expect(result.first.dig(:_context, :name)).to eq('public_branch')
      end
    end

    context 'when current_user is authenticated but not admin' do
      context 'when access to projects as GUEST and REPORTER' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 55, 99])
          reporter_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [2])

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_projects)

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_projects)
        end

        it 'returns all branch types' do
          result = builder.build
          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }

          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access to projects as GUEST only' do
        let(:guest_projects) { class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 55, 99]) }

        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_projects)
        end

        it 'returns public and internal auth branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch'
          )
        end

        context 'and has access with a custom role' do
          before do
            allow(auth).to receive(:get_projects_with_custom_roles)
              .with(guest_projects)
              .and_return(guest_projects)
          end

          it 'returns public and internal auth branch types' do
            result = builder.build

            branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
            expect(branch_contexts).to contain_exactly(
              'public_and_internal_branch',
              'public_and_internal_authorized_branch',
              'private_authorized_branch'
            )
          end
        end
      end

      context 'when access to projects as REPORTER only' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          reporter_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [2])

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_projects)
        end

        it 'returns private auth branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access to group as GUEST and REPORTER' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          guest_groups = class_double(ApplicationRecord, exists?: true)
          reporter_groups = class_double(ApplicationRecord, exists?: true)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_groups)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(guest_groups, hash_including(search_level: :group))
            .and_return(%w[123- 456-])

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(reporter_groups, hash_including(search_level: :group))
            .and_return(['789-'])
        end

        it 'returns all branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access group to as GUEST only' do
        let(:guest_groups) { class_double(ApplicationRecord, exists?: true) }

        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(guest_groups, hash_including(search_level: :group))
            .and_return(%w[123- 456-])
        end

        it 'returns all public and internal branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch'
          )
        end

        context 'and has access with a custom role' do
          before do
            allow(auth).to receive(:get_groups_with_custom_roles)
              .with(guest_groups)
              .and_return(guest_groups)
          end

          it 'returns public and internal auth branch types' do
            result = builder.build

            branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
            expect(branch_contexts).to contain_exactly(
              'public_and_internal_branch',
              'public_and_internal_authorized_branch',
              'private_authorized_branch'
            )
          end
        end
      end

      context 'when access to group as REPORTER only' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          reporter_groups = class_double(ApplicationRecord, exists?: true)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(reporter_groups, hash_including(search_level: :group))
            .and_return(%w[1- 56- 99-])
        end

        it 'returns all branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'private_authorized_branch'
          )
        end
      end
    end

    context 'when no authorization filters are available' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(false)
      end

      it 'returns only public and internal branches' do
        result = builder.build

        branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
        expect(branch_contexts).to contain_exactly('public_and_internal_branch')
      end
    end
  end
end
