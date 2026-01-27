# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerController, feature_category: :continuous_integration do
  describe 'validations' do
    subject { build(:ci_runner_controller) }

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
  end

  describe 'associations' do
    subject { build(:ci_runner_controller) }

    it { is_expected.to have_many(:tokens).class_name('Ci::RunnerControllerToken').inverse_of(:runner_controller) }

    it 'has one instance_level_scoping' do
      is_expected.to have_one(:instance_level_scoping).class_name('Ci::RunnerControllerInstanceLevelScoping')
                                                .inverse_of(:runner_controller)
    end
  end

  describe 'state enum' do
    it 'defines the correct states' do
      expect(described_class.states).to eq(
        'disabled' => 0,
        'enabled' => 1,
        'dry_run' => 2
      )
    end

    it 'defaults to disabled' do
      controller = described_class.new

      expect(controller.state).to eq('disabled')
      expect(controller).to be_disabled
    end

    it 'can be set to enabled' do
      controller = build(:ci_runner_controller, state: :enabled)

      expect(controller.state).to eq('enabled')
      expect(controller).to be_enabled
    end

    it 'can be set to dry_run' do
      controller = build(:ci_runner_controller, state: :dry_run)

      expect(controller.state).to eq('dry_run')
      expect(controller).to be_dry_run
    end
  end

  describe 'scopes' do
    let_it_be(:enabled_controller) { create(:ci_runner_controller, :enabled) }
    let_it_be(:disabled_controller) { create(:ci_runner_controller) }
    let_it_be(:dry_run_controller) { create(:ci_runner_controller, :dry_run) }

    describe '.enabled' do
      subject(:enabled) { described_class.enabled }

      it 'returns only enabled runner controllers' do
        is_expected.to contain_exactly(enabled_controller)
      end
    end

    describe '.disabled' do
      subject(:disabled) { described_class.disabled }

      it 'returns only disabled runner controllers' do
        is_expected.to contain_exactly(disabled_controller)
      end
    end

    describe '.dry_run' do
      subject(:dry_run) { described_class.dry_run }

      it 'returns only dry_run runner controllers' do
        is_expected.to contain_exactly(dry_run_controller)
      end
    end

    describe '.active' do
      subject(:active) { described_class.active }

      context 'when controllers in different states exist' do
        it 'returns enabled and dry_run runner controllers' do
          is_expected.to contain_exactly(enabled_controller, dry_run_controller)
        end
      end

      context 'when no active controllers exist' do
        before do
          described_class.active.delete_all
        end

        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end
    end
  end
end
