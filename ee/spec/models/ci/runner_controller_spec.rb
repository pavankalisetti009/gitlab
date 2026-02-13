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

    it 'has many runner_level_scopings' do
      is_expected.to have_many(:runner_level_scopings).class_name('Ci::RunnerControllerRunnerLevelScoping')
                                               .inverse_of(:runner_controller)
    end

    context 'when runner controller has mutliple instance-type runner controller scopings' do
      let_it_be(:runner_controller) { create(:ci_runner_controller) }
      let_it_be(:instance_runner_1) { create(:ci_runner, :instance) }
      let_it_be(:instance_runner_2) { create(:ci_runner, :instance) }
      let_it_be(:instance_runner_scoping_1) do
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner_1)
      end

      let_it_be(:instance_runner_scoping_2) do
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner_2)
      end

      it 'returns all associated runner-level scopings' do
        expect(runner_controller.runner_level_scopings).to contain_exactly(
          instance_runner_scoping_1,
          instance_runner_scoping_2
        )
      end
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

    describe '.with_instance_scope' do
      subject(:with_instance_scope) { described_class.with_instance_scope }

      context 'when no controllers have instance-level scope' do
        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end

      context 'when some controllers have instance-level scope' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: enabled_controller)
          create(:ci_runner_controller_instance_level_scoping, runner_controller: disabled_controller)
        end

        it 'returns only controllers with instance-level scope' do
          is_expected.to contain_exactly(enabled_controller, disabled_controller)
        end
      end

      context 'when combined with active scope' do
        let!(:scoped_enabled) { create(:ci_runner_controller, :enabled) }
        let!(:scoped_disabled) { create(:ci_runner_controller, :disabled) }
        let!(:unscoped_enabled) { create(:ci_runner_controller, :enabled) }

        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: scoped_enabled)
          create(:ci_runner_controller_instance_level_scoping, runner_controller: scoped_disabled)
        end

        it 'returns only active controllers with instance-level scope' do
          expect(described_class.active.with_instance_scope).to contain_exactly(scoped_enabled)
        end
      end
    end
  end
end
