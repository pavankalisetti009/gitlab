# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SettingPolicy, :enable_admin_mode, feature_category: :"self-hosted_models" do
  subject(:policy) { described_class.new(current_user, duo_settings) }

  let_it_be(:duo_settings) { create(:ai_settings, duo_nano_features_enabled: true) }
  let_it_be_with_reload(:current_user) { create(:admin) }

  describe 'read_self_hosted_models_settings' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

    before do
      allow(Ability).to receive(:allowed?)
        .with(current_user, :manage_self_hosted_models_settings, :global)
        .and_return(can_manage_self_hosted_models_settings)
    end

    context 'when user is not authorized to manage Duo self-hosted settings' do
      let(:can_manage_self_hosted_models_settings) { false }

      it { is_expected.to be_disallowed(:read_self_hosted_models_settings) }
    end

    context 'when user is authorized to manage Duo self-hosted settings' do
      let(:can_manage_self_hosted_models_settings) { true }

      it { is_expected.to be_allowed(:read_self_hosted_models_settings) }
    end
  end

  describe 'read_duo_core_settings' do
    before do
      allow(Ability).to receive(:allowed?)
        .with(current_user, :manage_duo_core_settings, :global)
        .and_return(can_manage_duo_core_settings)
    end

    context 'when user is not authorized to manage Duo Core settings' do
      let(:can_manage_duo_core_settings) { false }

      it { is_expected.to be_disallowed(:read_duo_core_settings) }
    end

    context 'when user is authorized to manage Duo Core settings' do
      let(:can_manage_duo_core_settings) { true }

      it { is_expected.to be_allowed(:read_duo_core_settings) }
    end
  end
end
