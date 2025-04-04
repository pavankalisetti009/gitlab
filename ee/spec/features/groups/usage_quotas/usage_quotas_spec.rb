# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage Quotas', :js, :saas, feature_category: :consumables_cost_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  before_all do
    group.add_owner(user)
  end

  before do
    sign_in(user)
  end

  describe 'Pending members page' do
    context 'with pending members' do
      let!(:awaiting_member) { create(:group_member, :awaiting, group: group) }

      it 'lists awaiting members and approves them' do
        visit pending_members_group_usage_quotas_path(group)

        expect(find_by_testid('pending-members-content')).to have_text(awaiting_member.user.name)

        click_button 'Approve'
        click_button 'OK'
        wait_for_requests

        expect(awaiting_member.reload).to be_active
      end
    end
  end
end
