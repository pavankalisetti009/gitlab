# frozen_string_literal: true

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- View specs require real objects for proper rendering
require 'spec_helper'

RSpec.describe 'shared/milestones/_issuable.html.haml', feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:user_namespace_project) { create(:project) }

  subject(:rendered) { render 'shared/milestones/issuable', issuable: issuable, show_project_name: true }

  context 'when issuable is an epic' do
    let_it_be(:issuable) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

    it 'links to the epic' do
      url = ::Gitlab::UrlBuilder.build(issuable)
      expect(rendered).to have_css("a[href$='#{url}']", class: 'issue-link')
    end
  end

  context 'when issuable is an issue' do
    let_it_be_with_refind(:issuable) { create(:work_item, :issue, project: project) }

    let(:status) { build(:work_item_system_defined_lifecycle).default_open_status }

    it 'does not display status' do
      expect(rendered).not_to have_text(status.name)
    end

    context 'when work_item_status feature is available' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it 'shows name' do
        expect(rendered).to have_text(status.name)
      end

      it 'includes color' do
        expect(rendered).to include(status.color)
      end

      it 'includes category icon' do
        expect(rendered).to have_css(%(svg use[href*="##{status.icon_name}"]))
      end

      context 'when project is in user namespace' do
        let_it_be_with_refind(:issuable) { create(:work_item, :issue, project: user_namespace_project) }

        it 'does not display status' do
          expect(rendered).not_to have_text(status.name)
        end
      end
    end

    context 'when issuable is merge request' do
      let_it_be_with_refind(:issuable) do
        create(:merge_request, source_project: project, target_project: project)
      end

      it 'does not display status' do
        expect(rendered).not_to have_text(status.name)
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
