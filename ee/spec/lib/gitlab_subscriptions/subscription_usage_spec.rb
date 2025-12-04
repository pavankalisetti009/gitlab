# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsage, feature_category: :consumables_cost_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:group) { create(:group, developers: users.first(2)) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  describe '#start_date' do
    subject(:start_date) { subscription_usage.start_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

        it 'returns the start date' do
          expect(start_date).to be("2025-10-01")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end

      context 'when the client response is missing startDate' do
        let(:client_response) { { success: true, subscriptionUsage: { startDate: nil } } }

        it 'returns nil' do
          expect(start_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { startDate: "2025-10-01" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the start date' do
        expect(start_date).to be("2025-10-01")
      end
    end
  end

  describe '#end_date' do
    subject(:end_date) { subscription_usage.end_date }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

        it 'returns the end date' do
          expect(end_date).to be("2025-10-31")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end

      context 'when the client response is missing endDate' do
        let(:client_response) { { success: true, subscriptionUsage: { endDate: nil } } }

        it 'returns nil' do
          expect(end_date).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { endDate: "2025-10-31" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the end date' do
        expect(end_date).to be("2025-10-31")
      end
    end
  end

  describe '#purchase_credits_path' do
    subject(:purchase_credits_path) { subscription_usage.purchase_credits_path }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: "/mock/path" } } }

        it 'returns the end date' do
          expect(purchase_credits_path).to be("/mock/path")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end

      context 'when the client response is missing purchaseCreditsPath' do
        let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: nil } } }

        it 'returns nil' do
          expect(purchase_credits_path).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { purchaseCreditsPath: "/mock/path" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the end date' do
        expect(purchase_credits_path).to be("/mock/path")
      end
    end
  end

  describe '#enabled?' do
    where(:cdot_enabled_value, :return_value) do
      true  | true
      false | false
      nil   | false
    end

    with_them do
      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      context "when subscription portal returns #{params[:cdot_enabled_value]} for enabled" do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :instance,
            subscription_usage_client: subscription_usage_client
          )
        end

        let(:client_response) do
          { success: true, subscriptionUsage: { enabled: cdot_enabled_value } }
        end

        it "returns #{params[:return_value]} for enabled?" do
          expect(subscription_usage.enabled?).to be return_value
        end
      end
    end
  end

  describe '#outdated_client?' do
    where(:outdated_client) { [true, false] }

    with_them do
      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      context "when subscription portal returns #{params[:outdated_client]} for isOutdatedClient" do
        let(:subscription_usage) do
          described_class.new(
            subscription_target: :instance,
            subscription_usage_client: subscription_usage_client
          )
        end

        let(:client_response) do
          { success: true, subscriptionUsage: { isOutdatedClient: outdated_client } }
        end

        it "returns #{params[:outdated_client]} for outdated_client?" do
          expect(subscription_usage.outdated_client?).to be outdated_client
        end
      end
    end
  end

  describe '#last_event_transaction_at' do
    subject(:last_event_transaction_at) { subscription_usage.last_event_transaction_at }

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          { success: true, subscriptionUsage: { lastEventTransactionAt: "2025-10-01T16:19:59Z" } }
        end

        it 'returns the last updated time' do
          expect(last_event_transaction_at).to be("2025-10-01T16:19:59Z")
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(last_event_transaction_at).to be_nil
        end
      end

      context 'when the client response is missing lastEventTransactionAt' do
        let(:client_response) { { success: true, subscriptionUsage: { lastEventTransactionAt: nil } } }

        it 'returns nil' do
          expect(last_event_transaction_at).to be_nil
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) { { success: true, subscriptionUsage: { lastEventTransactionAt: "2025-10-01T16:19:59Z" } } }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns the last updated time' do
        expect(last_event_transaction_at).to be("2025-10-01T16:19:59Z")
      end
    end
  end

  describe '#monthly_waiver' do
    subject(:monthly_waiver) { subscription_usage.monthly_waiver }

    before do
      allow(subscription_usage_client).to receive(:get_monthly_waiver).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            monthlyWaiver: {
              totalCredits: 1000.55,
              creditsUsed: 25.32,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 25.32 }]
            }
          }
        end

        it 'returns a MonthlyWaiver struct with correct data' do
          expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
          expect(monthly_waiver).to have_attributes(
            total_credits: 1000.55,
            credits_used: 25.32,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(monthly_waiver.daily_usage.size).to eq(1)
          expect(monthly_waiver.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(monthly_waiver.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 25.32,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(monthly_waiver).to be_nil
        end
      end

      context 'when the client response is missing monthlyWaiver data' do
        let(:client_response) do
          {
            success: true,
            monthlyWaiver: nil
          }
        end

        it 'returns a MonthlyWaiver struct with no values' do
          expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
          expect(monthly_waiver).to have_attributes(
            total_credits: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          monthlyWaiver: {
            totalCredits: 2000.12,
            creditsUsed: 123.99,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 123.99 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a MonthlyWaiver struct with correct data' do
        expect(monthly_waiver).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyWaiver)
        expect(monthly_waiver).to have_attributes(
          total_credits: 2000.12,
          credits_used: 123.99,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(monthly_waiver.daily_usage.size).to eq(1)
        expect(monthly_waiver.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(monthly_waiver.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 123.99,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#monthly_commitment' do
    subject(:monthly_commitment) { subscription_usage.monthly_commitment }

    before do
      allow(subscription_usage_client).to receive(:get_monthly_commitment).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            monthlyCommitment: {
              totalCredits: 1000,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns a MonthlyCommitment struct with correct data' do
          expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
          expect(monthly_commitment).to have_attributes(
            total_credits: 1000,
            credits_used: 750,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(monthly_commitment.daily_usage.size).to eq(1)
          expect(monthly_commitment.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(monthly_commitment.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(monthly_commitment).to be_nil
        end
      end

      context 'when the client response is missing monthlyCommitment data' do
        let(:client_response) do
          {
            success: true,
            monthlyCommitment: nil
          }
        end

        it 'returns a MonthlyCommitment struct with no values' do
          expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
          expect(monthly_commitment).to have_attributes(
            total_credits: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          monthlyCommitment: {
            totalCredits: 2000,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a MonthlyCommitment struct with correct data' do
        expect(monthly_commitment).to be_a(GitlabSubscriptions::SubscriptionUsage::MonthlyCommitment)
        expect(monthly_commitment).to have_attributes(
          total_credits: 2000,
          credits_used: 1500,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(monthly_commitment.daily_usage.size).to eq(1)
        expect(monthly_commitment.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(monthly_commitment.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#overage' do
    subject(:overage) { subscription_usage.overage }

    before do
      allow(subscription_usage_client).to receive(:get_overage).and_return(client_response)
    end

    context 'when subscription_target is :namespace' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      context 'when the client returns a successful response' do
        let(:client_response) do
          {
            success: true,
            overage: {
              isAllowed: true,
              creditsUsed: 750,
              dailyUsage: [{ date: '2025-10-01', creditsUsed: 750 }]
            }
          }
        end

        it 'returns an Overage struct with correct data' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: true,
            credits_used: 750,
            daily_usage: be_an(Array),
            declarative_policy_subject: subscription_usage
          )

          expect(overage.daily_usage.size).to eq(1)
          expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
          expect(overage.daily_usage.first).to have_attributes(
            date: '2025-10-01',
            credits_used: 750,
            declarative_policy_subject: subscription_usage
          )
        end
      end

      context 'when the client returns an unsuccessful response' do
        let(:client_response) { { success: false } }

        it 'returns nil' do
          expect(overage).to be_nil
        end
      end

      context 'when the client response is missing overage data' do
        let(:client_response) do
          {
            success: true,
            overage: nil
          }
        end

        it 'returns an Overage struct with no values' do
          expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
          expect(overage).to have_attributes(
            is_allowed: nil,
            credits_used: nil,
            daily_usage: [],
            declarative_policy_subject: subscription_usage
          )
        end
      end
    end

    context 'when subscription_target is :instance' do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:license) { build_stubbed(:license) }
      let(:client_response) do
        {
          success: true,
          overage: {
            isAllowed: true,
            creditsUsed: 1500,
            dailyUsage: [{ date: '2025-10-01', creditsUsed: 1500 }]
          }
        }
      end

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns an Overage struct with correct data' do
        expect(overage).to be_a(GitlabSubscriptions::SubscriptionUsage::Overage)
        expect(overage).to have_attributes(
          is_allowed: true,
          credits_used: 1500,
          daily_usage: be_an(Array),
          declarative_policy_subject: subscription_usage
        )

        expect(overage.daily_usage.size).to eq(1)
        expect(overage.daily_usage.first).to be_a(GitlabSubscriptions::SubscriptionUsage::DailyUsage)
        expect(overage.daily_usage.first).to have_attributes(
          date: '2025-10-01',
          credits_used: 1500,
          declarative_policy_subject: subscription_usage
        )
      end
    end
  end

  describe '#users_usage' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    it 'initiates a UserUsage object with the correct params' do
      expect(GitlabSubscriptions::SubscriptionsUsage::UserUsage).to receive(:new)
        .with(subscription_usage: subscription_usage)

      subscription_usage.users_usage
    end
  end

  describe '#overage_terms_accepted' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    let(:client_response) do
      { success: true, subscriptionUsage: { overageTermsAccepted: value } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    where(:value) { [true, false] }

    with_them do
      it 'returns the raw value from metadata' do
        expect(subscription_usage.overage_terms_accepted).to eq(value)
      end
    end
  end

  describe '#can_accept_overage_terms' do
    where(:cdot_value, :return_value) do
      true  | true
      false | false
      nil   | false
    end

    with_them do
      let(:subscription_usage) do
        described_class.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      let(:client_response) do
        { success: true, subscriptionUsage: { canAcceptOverageTerms: cdot_value } }
      end

      before do
        allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
      end

      it "returns #{params[:return_value]} when CDot returns #{params[:cdot_value].inspect}" do
        expect(subscription_usage.can_accept_overage_terms).to be(return_value)
      end
    end
  end

  describe '#dap_promo_enabled' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    let(:client_response) do
      { success: true, subscriptionUsage: { dapPromoEnabled: value } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_metadata).and_return(client_response)
    end

    where(:value) { [true, false] }

    with_them do
      it 'returns the raw value from metadata' do
        expect(subscription_usage.dap_promo_enabled).to eq(value)
      end
    end
  end

  describe '#subscription_portal_usage_dashboard_url' do
    let(:subscription_usage) do
      described_class.new(
        subscription_target: :instance,
        subscription_usage_client: subscription_usage_client
      )
    end

    subject(:url) { subscription_usage.subscription_portal_usage_dashboard_url }

    context 'when subscription cannot accept overage terms' do
      before do
        allow(subscription_usage).to receive(:can_accept_overage_terms).and_return(false)
      end

      it 'returns nil' do
        expect(url).to be_nil
      end
    end

    context 'when subscription can accept overage terms but path is blank' do
      before do
        allow(subscription_usage).to receive_messages(can_accept_overage_terms: true, usage_dashboard_path: nil)
      end

      it 'returns nil' do
        expect(url).to be_nil
      end
    end

    context 'when subscription can accept overage terms and path is present' do
      before do
        allow(subscription_usage).to receive_messages(can_accept_overage_terms: true,
          usage_dashboard_path: '/subscriptions/A-S00012345/usage')
      end

      it 'returns the full Subscription Portal URL' do
        expect(url).to eq(
          "#{::Gitlab::SubscriptionPortal.default_production_customer_portal_url}/subscriptions/A-S00012345/usage"
        )
      end
    end
  end
end
