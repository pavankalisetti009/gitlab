# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::GroupCalloutsHelper, :saas, feature_category: :groups_and_projects do
  let_it_be(:group) { build_stubbed(:group, :private, name: 'private namespace') }
  let_it_be(:user) { build(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#show_compliance_framework_settings_moved_callout?' do
    subject(:show_callout) { helper.show_compliance_framework_settings_moved_callout?(group) }

    context 'when alert can be shown' do
      before do
        allow(helper).to receive(:user_dismissed_for_group)
          .with('compliance_framework_settings_moved_callout', group)
          .and_return(false)
      end

      it 'returns true' do
        expect(show_callout).to be true
      end
    end

    context 'when alert is dismissed' do
      before do
        allow(helper).to receive(:user_dismissed_for_group)
          .with('compliance_framework_settings_moved_callout', group)
          .and_return(true)
      end

      it 'returns false' do
        expect(show_callout).to be false
      end
    end
  end

  describe '#show_enable_duo_banner?' do
    subject(:show_enable_duo_banner?) do
      helper.show_enable_duo_banner?(group, 'enable_duo_banner')
    end

    before do
      stub_saas_features(gitlab_duo_saas_only: true)
      allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(true)
      allow(group).to receive_message_chain(:namespace_settings, :duo_core_features_enabled).and_return(nil)
      allow(helper).to receive(:user_dismissed_for_group).with('enable_duo_banner', group).and_return(false)
      allow(group).to receive(:paid?).and_return(true)
    end

    context 'when all conditions are met' do
      it 'returns true' do
        expect(show_enable_duo_banner?).to be true
      end
    end

    context 'when Saas feature `gitlab_duo_saas_only` is not available' do
      before do
        stub_saas_features(gitlab_duo_saas_only: false)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when feature flag `allow_duo_base_access` is not enabled' do
      before do
        stub_feature_flags(allow_duo_base_access: false)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when the current user is not an admin' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when namespace settings `duo_nano_features_enabled` is not nil' do
      before do
        allow(group).to receive_message_chain(:namespace_settings, :duo_core_features_enabled).and_return(true)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when alert is dismissed' do
      before do
        allow(helper).to receive(:user_dismissed_for_group).with('enable_duo_banner', group).and_return(true)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when group is not paid' do
      before do
        allow(group).to receive(:paid?).and_return(false)
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end

    context 'when group is on a trial' do
      before do
        build_stubbed(:gitlab_subscription,
          namespace: group,
          trial_starts_on: Time.current,
          trial_ends_on: Time.current + 1.day,
          trial: true
        )
      end

      it 'returns false' do
        expect(show_enable_duo_banner?).to be false
      end
    end
  end
end
