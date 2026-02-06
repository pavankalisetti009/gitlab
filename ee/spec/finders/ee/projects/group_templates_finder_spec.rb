# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupTemplatesFinder, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }

  let_it_be(:group, reload: true) do
    create(:group, name: 'root-group', project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
  end

  let_it_be(:subgroup, reload: true) do
    create(:group, parent: group, name: 'subgroup', project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
  end

  let_it_be(:subsubgroup) do
    create(
      :group, parent: subgroup, name: 'subsubgroup',
      project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS
    )
  end

  let_it_be(:other_group) { create(:group, name: 'other-group') }

  let_it_be(:template_group_root) { create(:group, parent: group, name: 'template-group-root') }
  let_it_be(:template_group_sub) { create(:group, parent: subgroup, name: 'template-group-sub') }
  let_it_be(:template_group_other) { create(:group, parent: other_group, name: 'template-group-other') }

  let_it_be(:template_project_root) { create(:project, namespace: template_group_root, name: 'template-root') }
  let_it_be(:template_project_sub) { create(:project, namespace: template_group_sub, name: 'template-sub') }
  let_it_be(:template_project_other) { create(:project, namespace: template_group_other, name: 'template-other') }

  let_it_be(:archived_project) { create(:project, :archived, namespace: template_group_root, name: 'archived') }
  let_it_be(:marked_for_deletion_project) do
    create(:project, :archived, namespace: template_group_root, name: 'deleted', marked_for_deletion_at: 1.day.ago)
  end

  subject(:execute) { described_class.new(user, group_id).execute }

  before_all do
    group.update!(custom_project_templates_group_id: template_group_root.id)
    subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
    other_group.update!(custom_project_templates_group_id: template_group_other.id)
  end

  before do
    stub_licensed_features(group_project_templates: true)
  end

  describe '#execute' do
    context 'when group_id is nil' do
      let(:group_id) { nil }

      it { is_expected.to eq(Project.none) }
    end

    context 'when group_id is invalid' do
      let(:group_id) { non_existing_record_id }

      it { is_expected.to eq(Project.none) }
    end

    context 'when user cannot create projects in the group' do
      let(:group_id) { group.id }

      it { is_expected.to eq(Project.none) }
    end

    context 'when group_project_templates feature is not available' do
      let(:group_id) { group.id }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(group_project_templates: false)
      end

      it { is_expected.to eq(Project.none) }
    end

    context 'when user can create projects in the group' do
      before_all do
        group.add_developer(user)
      end

      context 'for a root group' do
        let(:group_id) { group.id }

        it 'only includes non-archived and projects not marked for deletion' do
          is_expected.to contain_exactly(template_project_root)
        end
      end

      context 'for a subgroup' do
        let(:group_id) { subgroup.id }

        before_all do
          subgroup.add_developer(user)
        end

        it { is_expected.to contain_exactly(template_project_root, template_project_sub) }

        context 'with multiple projects per template group' do
          let_it_be(:template_project_sub2) { create(:project, namespace: template_group_sub, name: 'template-sub2') }
          let_it_be(:template_project_root2) do
            create(:project, namespace: template_group_root, name: 'template-root2')
          end

          it 'orders by namespace_id first, then by id within each namespace' do
            result = execute.to_a

            expect(result.size).to eq(4)
            expect(result).to eq([template_project_root, template_project_root2, template_project_sub,
              template_project_sub2])

            expect(result[0].namespace_id).to be < result[2].namespace_id
            expect(result[0].id).to be < result[1].id
            expect(result[2].id).to be < result[3].id
          end
        end
      end

      context 'for a deeply nested group' do
        let(:group_id) { subsubgroup.id }

        before_all do
          subsubgroup.add_developer(user)
        end

        it 'returns template projects from all ancestors in the hierarchy' do
          is_expected.to contain_exactly(template_project_root, template_project_sub)
        end

        context 'when only some ancestors have templates configured' do
          let_it_be(:template_project_subsub) do
            template_group_subsub = create(:group, parent: subsubgroup, name: 'template-group-subsub')
            subsubgroup.update!(custom_project_templates_group_id: template_group_subsub.id)
            create(:project, namespace: template_group_subsub, name: 'template-project-subsub')
          end

          before_all do
            subgroup.update!(custom_project_templates_group_id: nil)
          end

          after(:all) do
            subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
          end

          it 'returns only template projects from ancestors with templates configured' do
            is_expected.to contain_exactly(template_project_root, template_project_subsub)
          end
        end
      end

      context 'when no ancestors have templates configured' do
        let(:group_id) { subsubgroup.id }

        before_all do
          group.update!(custom_project_templates_group_id: nil)
          subgroup.update!(custom_project_templates_group_id: nil)
        end

        after(:all) do
          group.update!(custom_project_templates_group_id: template_group_root.id)
          subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'with different permission levels' do
      let(:group_id) { group.id }

      context 'when user is a maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it { is_expected.to contain_exactly(template_project_root) }
      end

      context 'when user is an owner' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to contain_exactly(template_project_root) }
      end

      context 'when user is a guest' do
        before_all do
          group.add_guest(user)
        end

        it { is_expected.to eq(Project.none) }
      end

      context 'when user is a reporter' do
        before_all do
          group.add_reporter(user)
        end

        it { is_expected.to eq(Project.none) }
      end
    end

    describe 'Query Performance' do
      it 'avoids N+1 database queries when additional groups and projects are present',
        :request_store, :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          described_class.new(user, group.id).execute
        end

        create(:project, :empty_repo, namespace: template_group_root)
        create(:project, :empty_repo, namespace: template_group_sub)

        expect { described_class.new(user, subgroup.id).execute }.to issue_same_number_of_queries_as(control)
      end
    end
  end
end
