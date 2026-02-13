# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllerRunnerLevelScoping, feature_category: :continuous_integration do
  describe 'associations' do
    subject { build(:ci_runner_controller_runner_level_scoping) }

    it 'belongs to runner_controller' do
      is_expected.to belong_to(:runner_controller).class_name('Ci::RunnerController')
                                                  .inverse_of(:runner_level_scopings)
                                                  .optional(false)
    end

    it 'belongs to runner' do
      is_expected.to belong_to(:runner).class_name('Ci::Runner')
                                       .inverse_of(:runner_controller_runner_level_scopings)
                                       .optional(false)
    end
  end

  describe 'validations' do
    subject { build(:ci_runner_controller_runner_level_scoping, runner_type: 'instance_type') }

    it { is_expected.to validate_uniqueness_of(:runner_controller_id).scoped_to(:runner_id, :runner_type) }
  end

  describe '#set_runner_type' do
    let_it_be(:runner) { create(:ci_runner, :instance) }

    context 'when runner_type is not set' do
      let_it_be(:runner_level_scoping) { build(:ci_runner_controller_runner_level_scoping, runner: runner) }

      it 'sets runner_type from the runner' do
        expect { runner_level_scoping.valid? }.to change { runner_level_scoping.runner_type }.to('instance_type')
      end
    end

    context 'when it is already set' do
      let_it_be(:runner_level_scoping) do
        build(:ci_runner_controller_runner_level_scoping, runner_type: :instance_type)
      end

      it 'does not change the runner_type value' do
        expect { runner_level_scoping.valid? }.not_to change { runner_level_scoping.runner_type }
      end
    end
  end
end
