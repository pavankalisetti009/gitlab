# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::EventEligibilityChecker, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  describe '#eligible?' do
    let(:checker) { described_class.new }

    subject { checker.eligible?(event_name) }

    context 'when fully eligible due to produce usage data' do
      let(:event_name) { 'perform_completion_worker' }

      before do
        stub_application_setting(snowplow_enabled: false, gitlab_product_usage_data_enabled: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when app_id is not passed' do
      where(:event_name, :self_hosted_duo, :result) do
        'perform_completion_worker' | false | true
        'perform_completion_worker' | true | false
        'some_other_event'          | false | false
        'some_other_event'          | true | false
      end

      before do
        stub_application_setting(
          snowplow_enabled?: false, gitlab_product_usage_data_enabled?: false
        )
        create(:ai_self_hosted_model) if self_hosted_duo
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when app_id is passed' do
      subject { checker.eligible?(event_name, app_id) }

      before do
        stub_application_setting(
          snowplow_enabled?: false, gitlab_product_usage_data_enabled?: false
        )
        event_definition = instance_double(
          Gitlab::Tracking::EventDefinition,
          action: 'perform_completion_worker',
          duo_event?: true
        )
        allow(Gitlab::Tracking::EventDefinition).to receive(:definitions).and_return([event_definition])
        create(:ai_self_hosted_model) if self_hosted_duo
      end

      where(:event_name, :app_id, :self_hosted_duo, :result) do
        'click_button'                  | 'gitlab_ide_extension' | false | true
        'click_button'                  | 'gitlab_ide_extension' | true  | false
        'suggestion_shown'              | 'gitlab_ide_extension' | false | true
        'suggestion_shown'              | 'gitlab_ide_extension' | true  | false
        'some_non_ide_extension_event'  | 'gitlab_ide_extension' | false | false
        'some_non_ide_extension_event'  | 'gitlab_ide_extension' | true  | false
        'click_button'                  | 'some_other_app'       | false | false
        'suggestion_shown'              | 'some_other_app'       | false | false
        'some_non_ide_extension_event'  | 'some_other_app'       | false | false
        'some_non_ide_extension_event'  | 'some_other_app'       | true  | false
        'perform_completion_worker'     | 'some_other_app'       | false | true
        'perform_completion_worker'     | 'some_other_app'       | true  | false
        'perform_completion_worker'     | 'gitlab_ide_extension' | false | false
        'perform_completion_worker'     | 'gitlab_ide_extension' | true  | false
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when collect_product_usage_events feature flag is disabled' do
      where(:event_name, :product_usage_data_enabled, :result) do
        'perform_completion_worker' | true  | false
        'perform_completion_worker' | false | false
        'some_other_event'          | true  | false
        'some_other_event'          | false | false
      end

      before do
        stub_feature_flags(collect_product_usage_events: false)
        stub_application_setting(
          snowplow_enabled?: false, gitlab_product_usage_data_enabled?: product_usage_data_enabled
        )
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end
  end
end
