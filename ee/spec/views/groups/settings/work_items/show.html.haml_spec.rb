# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/work_items/show.html.haml', feature_category: :team_planning do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }

  before do
    assign(:group, group)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_title)
  end

  context 'when work_items_consolidated_list is enabled' do
    before do
      stub_feature_flags(work_item_planning_view: true)
      allow(group).to receive(:work_items_consolidated_list_enabled?).with(user).and_return(true)
    end

    it 'sets "Work items settings" as page title' do
      render

      expect(view).to have_received(:page_title).with(s_("WorkItem|Work items settings"))
    end

    it 'sets "Work items settings" as breadcrumb title' do
      render

      expect(view).to have_received(:breadcrumb_title).with(s_("WorkItem|Work items settings"))
    end
  end

  context 'when work_items_consolidated_list is disabled' do
    before do
      stub_feature_flags(work_item_planning_view: false)
      allow(group).to receive(:work_items_consolidated_list_enabled?).with(user).and_return(false)
    end

    it 'sets "Issues settings" as page title' do
      render

      expect(view).to have_received(:page_title).with(s_("WorkItem|Issues settings"))
    end

    it 'sets "Issues settings" as breadcrumb title' do
      render

      expect(view).to have_received(:breadcrumb_title).with(s_("WorkItem|Issues settings"))
    end
  end
end
