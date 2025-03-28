# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsHelper, feature_category: :acquisition do
  using RSpec::Parameterized::TableSyntax
  include Devise::Test::ControllerHelpers

  describe '#show_tier_badge_for_new_trial?' do
    where(:trials_available?, :paid?, :private?, :never_had_trial?, :authorized, :result) do
      false | false | true | true | true | false
      true | true | true | true | true | false
      true | false | false | true | true | false
      true | false | true | false | true | false
      true | false | true | true | false | false
      true | false | true | true | true | true
    end

    with_them do
      let(:namespace) { build(:namespace) }
      let(:user) { build(:user) }

      before do
        stub_saas_features(subscriptions_trials: trials_available?)
        allow(namespace).to receive(:paid?).and_return(paid?)
        allow(namespace).to receive(:private?).and_return(private?)
        allow(namespace).to receive(:never_had_trial?).and_return(never_had_trial?)
        allow(helper).to receive(:can?).with(user, :read_billing, namespace).and_return(authorized)
      end

      subject { helper.show_tier_badge_for_new_trial?(namespace, user) }

      it { is_expected.to be(result) }
    end
  end

  describe '#glm_source' do
    let(:host) { ::Gitlab.config.gitlab.host }

    it 'return gitlab config host' do
      glm_source = helper.glm_source

      expect(glm_source).to eq(host)
    end
  end

  describe '#duo_trial_namespace_selector_data' do
    let(:parsed_selector_data) { Gitlab::Json.parse(selector_data[:items]) }

    subject(:selector_data) { helper.duo_trial_namespace_selector_data(eligible_namespaces, nil) }

    context 'when there are eligible namespaces' do
      let(:namespace) { build(:namespace) }
      let(:eligible_namespaces) { [namespace] }

      it 'returns selector data with the eligible namespace' do
        is_expected.to include(any_trial_eligible_namespaces: 'true')
        expect(parsed_selector_data).to eq([{ 'text' => namespace.name, 'value' => namespace.id.to_s }])
      end
    end

    context 'when there are no eligible namespaces' do
      let(:eligible_namespaces) { [] }

      it 'returns empty selector data' do
        is_expected.to include(any_trial_eligible_namespaces: 'false')
        expect(parsed_selector_data).to be_empty
      end
    end
  end

  describe '#trial_form_errors_message' do
    let(:result) { ServiceResponse.error(message: ['some error']) }

    subject { helper.trial_form_errors_message(result) }

    it 'returns error message from the result directly' do
      is_expected.to eq('some error')
    end

    context 'when the error has :generic_trial_error as reason' do
      let(:message) { ['Some Error 1', 'Some Error 2'] }
      let(:link) { '<a target="_blank" rel="noopener noreferrer" href="https://support.gitlab.com">GitLab Support</a>' }

      let(:result) do
        ServiceResponse.error(message: message,
          reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
      end

      it 'displays the error message and a support message' do
        is_expected.to eq("Please reach out to #{link} for assistance: Some Error 1 and Some Error 2.")
      end

      context 'without message' do
        let(:message) { [] }

        it 'displays only a support message' do
          is_expected.to eq("Please reach out to #{link} for assistance.")
        end
      end
    end
  end
end
