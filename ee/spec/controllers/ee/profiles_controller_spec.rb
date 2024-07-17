# frozen_string_literal: true

require('spec_helper')

RSpec.describe ProfilesController, feature_category: :user_profile do
  let(:user) { create(:user) }

  describe 'POST join_early_access_program' do
    before do
      sign_in(user)
    end

    it 'opt-ins current user to early access program' do
      expect(::Users::JoinEarlyAccessProgramService)
        .to receive(:new).with(user).and_call_original

      post :join_early_access_program

      expect(response).to have_gitlab_http_status(:ok)
      expect(user.user_preference.early_access_program_participant).to be(true)
    end
  end
end
