# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::ApplicationSetting, feature_category: :shared do # rubocop:disable RSpec/FeatureCategory -- Application Settings are shared, describe block provide proper category.
  let_it_be(:application_setting, reload: true) { create(:application_setting) }

  subject(:output) { described_class.new(application_setting).as_json }

  shared_examples 'licensed feature exposing application settings' do |licensed_feature, settings|
    context "when #{licensed_feature} feature is enabled" do
      before do
        stub_licensed_features(licensed_feature => true)
      end

      it "exposes the #{licensed_feature} settings", :aggregate_failures do
        settings.each do |setting|
          expect(subject[setting]).to eq(application_setting.public_send(setting))
        end
      end
    end

    context "when #{licensed_feature} feature is disabled" do
      before do
        stub_licensed_features(licensed_feature => false)
      end

      it "does not expose the #{licensed_feature} settings", :aggregate_failures do
        settings.each do |setting|
          expect(subject[setting]).to be_nil
        end
      end
    end
  end

  describe 'dependency scanning settings', feature_category: :software_composition_analysis do
    it_behaves_like 'licensed feature exposing application settings', :dependency_scanning, %i[
      dependency_scanning_sbom_scan_api_download_limit
      dependency_scanning_sbom_scan_api_upload_limit
    ]
  end
end
