# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppConfig::CascadeDuoSettingsWorker, feature_category: :ai_abstraction_layer do
  let(:setting_attributes) { { "duo_features_enabled" => true } }

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls cascade_for_instance on service with the correct argument' do
      expect_next_instance_of(Ai::CascadeDuoSettingsService, setting_attributes) do |service|
        expect(service).to receive(:cascade_for_instance)
      end

      worker.perform(setting_attributes)
    end
  end
end
