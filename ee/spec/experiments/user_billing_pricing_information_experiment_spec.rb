# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserBillingPricingInformationExperiment, :experiment, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let(:has_free_or_trial_groups) { true }

  subject(:experiment_instance) { experiment(:user_billing_pricing_information, actor: user) }

  before do
    allow(user).to receive_message_chain(:owned_groups, :free_or_trial, :empty?)
      .and_return(!has_free_or_trial_groups)
  end

  describe 'exclusions' do
    context 'when user is a paid user (no free or trial groups)' do
      let(:has_free_or_trial_groups) { false }

      it 'excludes the user from the experiment' do
        expect(experiment_instance).to be_excluded
      end
    end

    context 'when user has free or trial groups' do
      let(:has_free_or_trial_groups) { true }

      it 'includes the user in the experiment' do
        expect(experiment_instance).not_to be_excluded
      end
    end
  end

  describe 'behaviors' do
    let(:has_free_or_trial_groups) { true }

    context 'with control experience' do
      before do
        stub_experiments(user_billing_pricing_information: :control)
      end

      it 'runs control behavior without error' do
        expect(experiment_instance).to register_behavior(:control).with(nil)
        expect { experiment_instance.run }.not_to raise_error
      end
    end

    context 'with candidate experience' do
      before do
        stub_experiments(user_billing_pricing_information: :candidate)
      end

      it 'runs candidate behavior without error' do
        expect(experiment_instance).to register_behavior(:candidate).with(nil)
        expect { experiment_instance.run }.not_to raise_error
      end
    end
  end
end
