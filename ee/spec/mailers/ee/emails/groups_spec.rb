# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe Emails::Groups, feature_category: :groups_and_projects do
  include EmailSpec::Matchers

  describe '#group_scheduled_for_deletion' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group_with_deletion_schedule, owners: user) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    let_it_be(:deletion_adjourned_period) { 7 }
    let_it_be(:deletion_date) { Time.current + deletion_adjourned_period.days }

    before do
      stub_application_setting(deletion_adjourned_period: deletion_adjourned_period)
    end

    subject { Notify.group_scheduled_for_deletion(user.id, group.id) }

    it 'has the expected content', :aggregate_failures, :freeze_time do
      is_expected.to have_subject("#{group.name} | Group scheduled for deletion")
      is_expected.to have_body_text(
        "has been marked for deletion and will be removed in #{deletion_adjourned_period} days."
      )
      is_expected.to have_body_text(deletion_date.strftime('%B %-d, %Y'))
    end
  end
end
