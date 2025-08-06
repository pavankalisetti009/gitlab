# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::WorkItems::LifecycleAndStatusPolicy, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:read_actions) { %i[read_work_item_lifecycle read_work_item_status] }
  let_it_be(:admin_actions) { %i[admin_work_item_lifecycle] }
  let_it_be(:all_actions) { read_actions + admin_actions }

  context 'with group' do
    include_context 'GroupPolicy context'

    subject { ::GroupPolicy.new(current_user, group) }

    context 'when work item statuses are available' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      where(:role, :actions, :allowed) do
        :anonymous       | ref(:all_actions)   | false
        :guest           | ref(:read_actions)  | true
        :guest           | ref(:admin_actions) | false
        :maintainer      | ref(:all_actions)   | true
      end

      with_them do
        let(:current_user) { try(role) }

        it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
      end

      context 'with subgroup' do
        let_it_be(:root_maintainer) { maintainer }

        subject { ::GroupPolicy.new(current_user, subgroup) }

        where(:role, :actions, :allowed) do
          :anonymous           | ref(:all_actions)   | false
          :subgroup_guest      | ref(:read_actions)  | true
          :subgroup_guest      | ref(:admin_actions) | false
          :root_maintainer     | ref(:all_actions)   | true
          :subgroup_maintainer | ref(:read_actions)  | true
          :subgroup_maintainer | ref(:admin_actions) | false
        end

        with_them do
          let(:current_user) { try(role) }

          it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
        end
      end
    end

    context 'when work item statuses are not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      where(:role) { [:anonymous, :guest, :maintainer] }

      with_them do
        let(:current_user) { try(role) }

        it { is_expected.to be_disallowed(*all_actions) }
      end
    end
  end

  context 'with project' do
    include_context 'ProjectPolicy context'

    let(:project) { private_project_in_group }
    let_it_be(:root_maintainer) { inherited_maintainer }

    before do
      project.add_guest(guest)
      project.add_maintainer(maintainer)
    end

    subject { ::ProjectPolicy.new(current_user, project) }

    context 'when work item statuses are available' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      where(:role, :actions, :allowed) do
        :anonymous          | ref(:all_actions)   | false
        :guest              | ref(:read_actions)  | true
        :guest              | ref(:admin_actions) | false
        :root_maintainer    | ref(:all_actions)   | true
        :maintainer         | ref(:read_actions)  | true
        :maintainer         | ref(:admin_actions) | false
      end

      with_them do
        let(:current_user) { try(role) }

        it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
      end

      context 'with subgroup project' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }
        let_it_be(:subgroup_maintainer) { create(:user, maintainer_of: subgroup) }

        let(:project) { subgroup_project }

        where(:role, :actions, :allowed) do
          :anonymous           | ref(:all_actions)   | false
          :guest               | ref(:read_actions)  | true
          :guest               | ref(:admin_actions) | false
          :root_maintainer     | ref(:all_actions)   | true
          :subgroup_maintainer | ref(:read_actions)  | true
          :subgroup_maintainer | ref(:admin_actions) | false
          :maintainer          | ref(:read_actions)  | true
          :maintainer          | ref(:admin_actions) | false
        end

        with_them do
          let(:current_user) { try(role) }

          it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
        end
      end
    end

    context 'when work item statuses are not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      where(:role) { [:anonymous, :guest, :root_maintainer, :maintainer] }

      with_them do
        let(:current_user) { try(role) }

        it { is_expected.to be_disallowed(*all_actions) }
      end
    end
  end
end
