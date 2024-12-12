# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::ApplicationSettingsHelper, feature_category: :ai_abstraction_layer do
  using RSpec::Parameterized::TableSyntax

  let(:duo_availability) { :default_off }
  let(:instance_level_ai_beta_features_enabled) { false }
  let(:disabled_direct_code_suggestions) { false }
  let(:code_suggestions_service) { instance_double(CloudConnector::AvailableServices) }

  before do
    stub_ee_application_setting(duo_availability: duo_availability)
    stub_ee_application_setting(instance_level_ai_beta_features_enabled: instance_level_ai_beta_features_enabled)
    stub_ee_application_setting(disabled_direct_code_suggestions: disabled_direct_code_suggestions)
    allow(CloudConnector::AvailableServices)
      .to receive(:find_by_name).with(:code_suggestions).and_return(code_suggestions_service)
  end

  describe 'AI-Powered features settings for Self-Managed instances' do
    describe '#ai_powered_description' do
      subject { helper.ai_powered_description }

      it { is_expected.to include 'https://docs.gitlab.com/ee/user/ai_features.html' }
    end

    describe '#ai_powered_testing_agreement' do
      subject { helper.ai_powered_testing_agreement }

      it { is_expected.to include 'https://about.gitlab.com/handbook/legal/testing-agreement/' }
    end

    describe '#admin_ai_general_settings_helper_data' do
      subject(:admin_ai_general_settings_helper_data) { helper.admin_ai_general_settings_helper_data }

      it 'returns the expected data' do
        expect(admin_ai_general_settings_helper_data).to include(
          on_general_settings_page: 'true',
          configuration_settings_path: '/admin/gitlab_duo'
        )
      end
    end

    describe '#admin_ai_configuration_settings_helper_data' do
      subject(:admin_ai_configuration_settings_helper_data) { helper.admin_ai_configuration_settings_helper_data }

      before do
        allow(helper).to receive(:ai_settings_helper_data).and_return({ base_data: 'data' })
      end

      it 'returns the expected data' do
        expect(admin_ai_configuration_settings_helper_data).to include(
          on_general_settings_page: 'false',
          redirect_path: '/admin/gitlab_duo',
          base_data: 'data'
        )
      end
    end

    describe '#ai_settings_helper_data' do
      using RSpec::Parameterized::TableSyntax

      subject { helper.ai_settings_helper_data }

      where(:terms_accepted, :duo_pro_visible, :purchased, :expected_duo_pro_visible_value) do
        true | true | true | 'true'
        false | 'false' | false | 'false'
        true | '' | nil | ''
      end

      with_them do
        let(:expected_settings_helper_data) do
          {
            duo_availability: duo_availability.to_s,
            experiment_features_enabled: instance_level_ai_beta_features_enabled.to_s,
            are_experiment_settings_allowed: "true",
            disabled_direct_connection_method: disabled_direct_code_suggestions.to_s,
            self_hosted_models_enabled: terms_accepted.to_s,
            ai_terms_and_conditions_path: admin_ai_terms_and_conditions_path,
            duo_pro_visible: expected_duo_pro_visible_value
          }
        end

        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(terms_accepted)

          if purchased.nil?
            allow(CloudConnector::AvailableServices)
              .to receive(:find_by_name).with(:code_suggestions).and_return(nil)
          else
            allow(CloudConnector::AvailableServices)
              .to receive_message_chain(:find_by_name, :purchased?).and_return(purchased)
          end
        end

        it "returns the expected data" do
          is_expected.to eq(expected_settings_helper_data)
        end
      end
    end
  end

  describe '#admin_display_duo_addon_settings?' do
    subject(:display_duo_pro_settings) { helper.admin_display_duo_addon_settings? }

    let(:code_suggestions_service) { double('CodeSuggestionsService') } # rubocop:disable RSpec/VerifiedDoubles -- Stubbed to test purchases call

    before do
      allow(CloudConnector::AvailableServices)
        .to receive(:find_by_name)
        .with(:code_suggestions)
        .and_return(code_suggestions_service)
    end

    context 'when code suggestions service is available and purchased' do
      before do
        allow(code_suggestions_service).to receive(:purchased?).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when code suggestions service is available but not purchased' do
      before do
        allow(code_suggestions_service).to receive(:purchased?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'when code suggestions service is not available' do
      before do
        allow(CloudConnector::AvailableServices)
          .to receive(:find_by_name)
          .with(:code_suggestions)
          .and_return(nil)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#admin_duo_home_app_data' do
    let(:starts_at) { Date.current }
    let(:expires_at) { Date.current + 1.year }
    let(:license) { build(:gitlab_license, starts_at: starts_at, expires_at: expires_at) }
    let(:subscription_name) { 'Test Subscription Name' }

    before do
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive_messages(
        subscription_name: subscription_name,
        subscription_start_date: starts_at,
        subscription_end_date: expires_at
      )

      allow(helper).to receive_messages(
        admin_gitlab_duo_seat_utilization_index_path: '/admin/gitlab_duo/seat_utilization',
        admin_gitlab_duo_configuration_index_path: '/admin/gitlab_duo/configuration',
        duo_pro_bulk_user_assignment_available?: true,
        duo_availability: 'default_off',
        instance_level_ai_beta_features_enabled: true
      )

      allow(helper).to receive(:add_duo_pro_seats_url).with(subscription_name).and_return('https://customers.staging.gitlab.com/gitlab/subscriptions/A-S00613274/duo_pro_seats')
      allow(Gitlab::CurrentSettings).to receive_message_chain(:current,
        :disabled_direct_code_suggestions).and_return(false)
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
    end

    it 'returns a hash with all required keys and correct values' do
      expect(helper.admin_duo_home_app_data).to eq({
        duo_seat_utilization_path: '/admin/gitlab_duo/seat_utilization',
        duo_configuration_path: '/admin/gitlab_duo/configuration',
        add_duo_pro_seats_url: 'https://customers.staging.gitlab.com/gitlab/subscriptions/A-S00613274/duo_pro_seats',
        subscription_name: 'Test Subscription Name',
        is_bulk_add_on_assignment_enabled: 'true',
        subscription_start_date: starts_at,
        subscription_end_date: expires_at,
        duo_availability: 'default_off',
        direct_code_suggestions_enabled: 'false',
        experiment_features_enabled: 'true',
        self_hosted_models_enabled: 'true'
      })
    end
  end
end
