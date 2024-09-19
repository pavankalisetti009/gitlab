# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::Status, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:member) { create(:group_member) }
  let_it_be(:user) { member.user }

  context 'for delegations' do
    subject { described_class.new({}, nil, nil) }

    it { is_expected.to delegate_method(:tracking_label).to(:registration_type) }
    it { is_expected.to delegate_method(:product_interaction).to(:registration_type) }
    it { is_expected.to delegate_method(:setup_for_company_label_text).to(:registration_type) }
    it { is_expected.to delegate_method(:setup_for_company_help_text).to(:registration_type) }
    it { is_expected.to delegate_method(:redirect_to_company_form?).to(:registration_type) }
    it { is_expected.to delegate_method(:eligible_for_iterable_trigger?).to(:registration_type) }
    it { is_expected.to delegate_method(:show_opt_in_to_email?).to(:registration_type) }
    it { is_expected.to delegate_method(:show_joining_project?).to(:registration_type) }
    it { is_expected.to delegate_method(:hide_setup_for_company_field?).to(:registration_type) }
    it { is_expected.to delegate_method(:pre_parsed_email_opt_in?).to(:registration_type) }
    it { is_expected.to delegate_method(:apply_trial?).to(:registration_type) }
    it { is_expected.to delegate_method(:read_from_stored_user_location?).to(:registration_type) }
    it { is_expected.to delegate_method(:preserve_stored_location?).to(:registration_type) }
  end

  describe '.glm_tracking_params' do
    let(:params) { ActionController::Parameters.new(glm_source: 'source', glm_content: 'content', extra: 'param') }

    subject { described_class.glm_tracking_params(params) }

    it { is_expected.to eq(params.slice(:glm_source, :glm_content).permit!) }
  end

  describe '.registration_path_params' do
    let(:params) { ActionController::Parameters.new(glm_source: 'source', glm_content: 'content', extra: 'param') }
    let(:extra_params) { { another_extra: 'param' } }
    let(:onboarding_enabled) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled)
    end

    subject { described_class.registration_path_params(params: params) }

    context 'when onboarding is enabled' do
      let(:expected_params) { { glm_source: 'source', glm_content: 'content' } }

      it { is_expected.to eq(expected_params.stringify_keys) }

      context 'when extra params are passed' do
        let(:combined_params) { expected_params.merge(extra_params).stringify_keys }

        subject { described_class.registration_path_params(params: params, extra_params: extra_params) }

        it { is_expected.to eq(combined_params) }
      end
    end

    context 'when onboarding is disabled' do
      let(:onboarding_enabled) { false }

      it { is_expected.to eq({}) }

      context 'when extra params are passed' do
        subject { described_class.registration_path_params(params: params, extra_params: extra_params) }

        it { is_expected.to eq({}) }
      end
    end
  end

  describe '#continue_full_onboarding?' do
    let(:session_in_oauth) do
      { 'user_return_to' => ::Gitlab::Routing.url_helpers.oauth_authorization_path(some_param: '_param_') }
    end

    let(:session_not_in_oauth) { { 'user_return_to' => nil } }

    where(:registration_type, :session, :enabled?, :expected_result) do
      'free'         | ref(:session_not_in_oauth) | true  | true
      'free'         | ref(:session_in_oauth)     | true  | false
      'free'         | ref(:session_not_in_oauth) | false | false
      'free'         | ref(:session_in_oauth)     | false | false
      nil            | ref(:session_not_in_oauth) | true  | true
      nil            | ref(:session_in_oauth)     | true  | false
      nil            | ref(:session_not_in_oauth) | false | false
      nil            | ref(:session_in_oauth)     | false | false
      'trial'        | ref(:session_not_in_oauth) | true  | true
      'trial'        | ref(:session_in_oauth)     | true  | false
      'trial'        | ref(:session_not_in_oauth) | false | false
      'trial'        | ref(:session_in_oauth)     | false | false
      'invite'       | ref(:session_not_in_oauth) | true  | false
      'invite'       | ref(:session_in_oauth)     | true  | false
      'invite'       | ref(:session_not_in_oauth) | false | false
      'invite'       | ref(:session_in_oauth)     | false | false
      'subscription' | ref(:session_not_in_oauth) | true  | false
      'subscription' | ref(:session_in_oauth)     | true  | false
      'subscription' | ref(:session_not_in_oauth) | false | false
      'subscription' | ref(:session_in_oauth)     | false | false
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }
      let(:instance) { described_class.new({}, session, current_user) }

      before do
        stub_saas_features(onboarding: enabled?)
      end

      subject { instance.continue_full_onboarding? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#welcome_submit_button_text' do
    let(:continue_text) { _('Continue') }
    let(:get_started_text) { _('Get started!') }
    let(:session_in_oauth) do
      { 'user_return_to' => ::Gitlab::Routing.url_helpers.oauth_authorization_path(some_param: '_param_') }
    end

    let(:session_not_in_oauth) { { 'user_return_to' => nil } }

    where(:registration_type, :session, :expected_result) do
      'free'         | ref(:session_not_in_oauth) | ref(:continue_text)
      'free'         | ref(:session_in_oauth)     | ref(:get_started_text)
      nil            | ref(:session_not_in_oauth) | ref(:continue_text)
      nil            | ref(:session_in_oauth)     | ref(:get_started_text)
      'trial'        | ref(:session_not_in_oauth) | ref(:continue_text)
      'trial'        | ref(:session_in_oauth)     | ref(:get_started_text)
      'invite'       | ref(:session_not_in_oauth) | ref(:get_started_text)
      'invite'       | ref(:session_in_oauth)     | ref(:get_started_text)
      'subscription' | ref(:session_not_in_oauth) | ref(:continue_text)
      'subscription' | ref(:session_in_oauth)     | ref(:continue_text)
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }
      let(:instance) { described_class.new({}, session, current_user) }

      before do
        stub_saas_features(onboarding: true)
      end

      subject { instance.welcome_submit_button_text }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#registration_type' do
    where(:registration_type, :expected_klass) do
      'free'         | ::Onboarding::FreeRegistration
      nil            | ::Onboarding::FreeRegistration
      'trial'        | ::Onboarding::TrialRegistration
      'invite'       | ::Onboarding::InviteRegistration
      'subscription' | ::Onboarding::SubscriptionRegistration
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }

      specify do
        expect(described_class.new({}, nil, current_user).registration_type).to eq expected_klass
      end
    end
  end

  describe '#convert_to_automatic_trial?' do
    where(:registration_type, :setup_for_company?, :expected_result) do
      'free'         | false | false
      'free'         | true  | true
      nil            | false | false
      nil            | true  | true
      'trial'        | false | false
      'trial'        | true  | false
      'invite'       | false | false
      'invite'       | true  | false
      'subscription' | false | false
      'subscription' | true  | false
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }
      let(:instance) { described_class.new({}, nil, current_user) }

      before do
        allow(instance).to receive(:setup_for_company?).and_return(setup_for_company?)
      end

      subject { instance.convert_to_automatic_trial? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#setup_for_company?' do
    where(:params, :expected_result) do
      { user: { setup_for_company: true } }  | true
      { user: { setup_for_company: false } } | false
      { user: {} }                           | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.setup_for_company? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#joining_a_project?' do
    where(:params, :expected_result) do
      { joining_project: 'true' }  | true
      { joining_project: 'false' } | false
      {}                           | false
      { joining_project: '' }      | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.joining_a_project? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#initial_trial?' do
    let(:user_with_initial_trial) { build_stubbed(:user, onboarding_status_initial_registration_type: 'trial') }
    let(:user_with_initial_free) { build_stubbed(:user, onboarding_status_initial_registration_type: 'free') }

    before do
      stub_saas_features(onboarding: true)
    end

    where(:current_user, :expected_result) do
      ref(:user)                    | false
      ref(:user_with_initial_trial) | true
      ref(:user_with_initial_free)  | false
    end

    with_them do
      let(:instance) { described_class.new(nil, nil, current_user) }

      subject { instance.initial_trial? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#company_lead_product_interaction' do
    before do
      stub_saas_features(onboarding: true)
    end

    subject { described_class.new(nil, nil, user).company_lead_product_interaction }

    context 'when it is a true trial registration' do
      let(:user) do
        build_stubbed(
          :user, onboarding_status_initial_registration_type: 'trial', onboarding_status_registration_type: 'trial'
        )
      end

      it { is_expected.to eq('SaaS Trial') }
    end

    context 'when it is an automatic trial registration' do
      it { is_expected.to eq('SaaS Trial - defaulted') }
    end

    context 'when it is initially free registration_type' do
      let(:current_user) { build_stubbed(:user) { |u| u.onboarding_status_initial_registration_type = 'free' } }

      context 'when it has trial set from params' do
        it { is_expected.to eq('SaaS Trial - defaulted') }
      end

      context 'when it does not have trial set from params' do
        let(:params) { {} }

        it { is_expected.to eq('SaaS Trial - defaulted') }
      end

      context 'when it is now a trial registration_type' do
        let(:params) { {} }

        before do
          current_user.onboarding_status_registration_type = 'trial'
        end

        it { is_expected.to eq('SaaS Trial - defaulted') }
      end
    end
  end

  describe '#preregistration_tracking_label' do
    let(:params) { {} }
    let(:session) { {} }
    let(:instance) { described_class.new(params, session, nil) }

    subject(:preregistration_tracking_label) { instance.preregistration_tracking_label }

    it { is_expected.to eq('free_registration') }

    context 'when it is an invite' do
      let(:params) { { invite_email: 'some_email@example.com' } }

      it { is_expected.to eq('invite_registration') }
    end

    context 'when it is a subscription' do
      let(:session) { { 'user_return_to' => ::Gitlab::Routing.url_helpers.new_subscriptions_path } }

      it { is_expected.to eq('subscription_registration') }
    end
  end

  describe '#stored_user_location' do
    let(:return_to) { nil }
    let(:session) { { 'user_return_to' => return_to } }

    subject { described_class.new(nil, session, nil).stored_user_location }

    context 'when no user location is stored' do
      it { is_expected.to be_nil }
    end

    context 'when user location exists' do
      let(:return_to) { '/some/path' }

      it { is_expected.to eq(return_to) }
    end

    context 'when user location does not have value in session' do
      let(:session) { {} }

      it { is_expected.to be_nil }
    end
  end
end
