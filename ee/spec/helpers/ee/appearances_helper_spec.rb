# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::AppearancesHelper, feature_category: :shared do
  let_it_be(:appearance) { build_stubbed(:appearance) }
  let_it_be(:user) { build_stubbed(:user) }

  describe '#brand_title' do
    before do
      stub_saas_features(onboarding: true)
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'returns the sign-in page title' do
      allow(helper).to receive_message_chain(:request, :path).and_return(new_user_session_path)

      expect(helper.send(:brand_title)).to eq('Sign in to GitLab')
    end

    it 'returns the sign-up page title' do
      allow(helper).to receive_message_chain(:request, :path).and_return(new_user_registration_path)

      expect(helper.send(:brand_title)).to eq('Get started with GitLab')
    end

    it 'returns EE default brand title when onboarding feature is disabled' do
      allow(helper).to receive_message_chain(:request, :path).and_return('/dashboard')

      expect(helper.send(:brand_title)).to eq('GitLab Enterprise Edition')
    end

    it 'returns CE brand title when onboarding feature is disabled' do
      stub_saas_features(onboarding: false)
      allow(helper).to receive(:current_appearance).and_return(appearance)
      allow(helper).to receive_message_chain(:request, :path).and_return(new_user_session_path)

      expect(helper.send(:brand_title)).to eq(appearance.title)
    end
  end
end
