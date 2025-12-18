# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerController, feature_category: :continuous_integration do
  describe 'validations' do
    subject { build(:ci_runner_controller) }

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
  end

  describe 'enabled field' do
    it 'defaults to false' do
      controller = described_class.new

      expect(controller.enabled).to be false
    end

    it 'can be set to true' do
      controller = build(:ci_runner_controller, enabled: true)

      expect(controller.enabled).to be true
    end

    it 'can be set to false' do
      controller = build(:ci_runner_controller, enabled: false)

      expect(controller.enabled).to be false
    end
  end

  describe '.enabled' do
    subject(:enabled) { described_class.enabled }

    context 'when enabled and disabled controllers exist' do
      let!(:enabled_controller) { create(:ci_runner_controller, :enabled) }
      let!(:disabled_controller) { create(:ci_runner_controller) }

      it 'returns only enabled runner controllers' do
        is_expected.to include(enabled_controller)
        is_expected.not_to include(disabled_controller)
      end
    end

    context 'when no enabled controllers exist' do
      before do
        create(:ci_runner_controller)
      end

      it 'returns empty collection' do
        is_expected.to be_empty
      end
    end

    context 'when multiple enabled controllers exist' do
      let!(:enabled_controllers) { create_list(:ci_runner_controller, 3, :enabled) }

      before do
        create(:ci_runner_controller)
      end

      it 'returns all enabled controllers' do
        is_expected.to match_array(enabled_controllers)
      end
    end
  end
end
