# frozen_string_literal: true

RSpec.shared_examples 'targeted message interactions' do
  before do
    create(:targeted_message_namespace, namespace: group)
    sign_in(user)
  end

  it 'is not shown to non-owner', :with_trial_types do
    sign_in(non_owner)
    visit path

    expect(page).not_to have_content("Get access to Premium + GitLab Duo for")
  end

  it 'is shown to owner', :with_trial_types do
    visit path

    expect(page).to have_content("Get access to Premium + GitLab Duo for")
  end

  it 'dismisses when closed', :with_trial_types do
    visit path

    expect(page).to have_content("Get access to Premium + GitLab Duo for")

    find_by_testid('targeted_message_close_button').click

    expect(page).not_to have_content("Get access to Premium + GitLab Duo for")
  end

  context 'with disabled targeted message', :with_trial_types do
    before do
      stub_feature_flags(targeted_messages_admin_ui: false)
    end

    it 'is not shown' do
      visit path

      expect(page).not_to have_content("Get access to Premium + GitLab Duo for")
    end
  end
end
