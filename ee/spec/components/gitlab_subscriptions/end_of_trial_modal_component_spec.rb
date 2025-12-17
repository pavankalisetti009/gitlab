# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::EndOfTrialModalComponent, :aggregate_failures, feature_category: :acquisition do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group, gitlab_subscription: gitlab_subscription) }
  let(:gitlab_subscription) { build_stubbed(:gitlab_subscription, :expired_trial, :free) }
  let(:can_read_billing) { true }
  let(:recently_expired) { true }
  let(:plans_data) { [Hashie::Mash.new(id: 1, code: ::Plan::PREMIUM)] }
  let(:feature_name) { 'end_of_trial_modal' }

  before do
    allow(Ability).to receive(:allowed?).with(user, :read_billing, group).and_return(can_read_billing)
    allow(::GitlabSubscriptions::Trials).to receive(:recently_expired?).with(group).and_return(recently_expired)

    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
      allow(instance).to receive(:execute).and_return(plans_data)
    end
  end

  subject(:component) { render_inline(described_class.new(user: user, namespace: group)) && page }

  it { is_expected.not_to have_css('#js-end-of-trial-modal') }

  context 'when saas_gitlab_com_subscriptions feature is available', :saas_gitlab_com_subscriptions do
    context 'when owner' do
      context 'when recently expired group' do
        context 'when not dismissed' do
          context 'when CDot returns plans data' do
            let(:data_attributes) do
              ::Gitlab::Json.generate({
                featureName: feature_name,
                groupId: group.id,
                groupName: group.name,
                explorePlansPath: group_billings_path(group),
                upgradeUrl: GitlabSubscriptions::PurchaseUrlBuilder.new(
                  plan_id: plans_data.first.id,
                  namespace: group
                ).build
              })
            end

            it 'has expected modal data attributes' do
              is_expected.to have_css("#js-end-of-trial-modal[data-view-model='#{data_attributes}']")
            end
          end

          context 'when CDot does not return plans data' do
            let(:plans_data) { [] }

            it { is_expected.not_to have_css('#js-end-of-trial-modal') }
          end
        end

        context 'when dismissed' do
          before do
            allow(user)
              .to receive(:dismissed_callout_for_group?)
              .with(feature_name: feature_name, group: group)
              .and_return(true)
          end

          it { is_expected.not_to have_css('#js-end-of-trial-modal') }
        end
      end

      context 'when is not recently expired group' do
        let(:recently_expired) { false }

        it { is_expected.not_to have_css('#js-end-of-trial-modal') }
      end
    end

    context 'when not owner' do
      let(:can_read_billing) { false }

      it { is_expected.not_to have_css('#js-end-of-trial-modal') }
    end
  end
end
