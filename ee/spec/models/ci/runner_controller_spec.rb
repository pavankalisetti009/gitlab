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
end
