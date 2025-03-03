# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::GitlabHostedRunnerMonthlyUsage, factory_default: :keep, feature_category: :hosted_runners do
  let_it_be(:root_namespace) { create_default(:namespace) }
  let_it_be(:project) { create(:project) }
  let_it_be(:runner) { create(:ci_runner, :instance) }
  let(:other_runner) { create(:ci_runner, :instance) }

  subject(:usage) do
    described_class.new(
      project: project,
      root_namespace: project.root_namespace,
      runner: runner,
      billing_month: Date.current.beginning_of_month,
      notification_level: :warning,
      compute_minutes_used: 100.5,
      runner_duration_seconds: 6030
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:root_namespace).class_name('Namespace').inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:runner).class_name('Ci::Runner').inverse_of(:hosted_runner_monthly_usages) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:runner).on(:create) }
    it { is_expected.to validate_presence_of(:project).on(:create) }
    it { is_expected.to validate_presence_of(:root_namespace).on(:create) }
    it { is_expected.to validate_presence_of(:billing_month) }
    it { is_expected.to validate_presence_of(:compute_minutes_used) }

    it { is_expected.to validate_numericality_of(:compute_minutes_used).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:runner_duration_seconds).is_greater_than_or_equal_to(0).only_integer }

    describe 'billing_month format' do
      context 'when set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 1)
        end

        it 'is valid' do
          expect(usage).to be_valid
        end
      end

      context 'when not set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 2)
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include('must be the first day of the month')
        end
      end

      context 'when billing_month is blank' do
        before do
          usage.billing_month = nil
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include("can't be blank")
        end
      end
    end
  end

  describe 'scopes' do
    let(:billing_month) { Date.new(2025, 1, 1) }
    let(:namespace1) { create(:namespace) }
    let(:namespace2) { create(:namespace) }

    before do
      create(:ci_hosted_runner_monthly_usage,
        billing_month: billing_month,
        compute_minutes_used: 100,
        runner_duration_seconds: 6000,
        root_namespace: namespace1,
        runner: runner)
      create(:ci_hosted_runner_monthly_usage,
        billing_month: billing_month,
        compute_minutes_used: 200,
        runner_duration_seconds: 12000,
        root_namespace: namespace2,
        runner: other_runner)
    end

    describe '.instance_aggregate' do
      subject(:instance_aggregate) { described_class.instance_aggregate(billing_month, nil).to_a }

      it 'returns the correct aggregate data' do
        expect(instance_aggregate.count).to eq(1)
        expect(instance_aggregate.first.compute_minutes).to eq(300)
        expect(instance_aggregate.first.duration_seconds).to eq(18000)
        expect(instance_aggregate.first.root_namespace_id).to be_nil
      end

      context 'when runner_id is specified' do
        subject(:instance_aggregate) { described_class.instance_aggregate(billing_month, nil, runner.id).to_a }

        it 'returns data only for the specified runner' do
          expect(instance_aggregate.count).to eq(1)
          expect(instance_aggregate.first.compute_minutes).to eq(100)
          expect(instance_aggregate.first.duration_seconds).to eq(6000)
          expect(instance_aggregate.first.root_namespace_id).to be_nil
        end
      end
    end

    describe '.per_root_namespace' do
      subject(:per_root_namespace) { described_class.per_root_namespace(billing_month, nil).to_a }

      it 'returns the correct data per root namespace' do
        expect(per_root_namespace.count).to eq(2)
        expect(per_root_namespace.map(&:root_namespace_id))
          .to match_array([namespace1.id, namespace2.id])

        expect(per_root_namespace.find do |usage|
          usage.root_namespace_id == namespace1.id
        end.compute_minutes).to eq(100)

        expect(per_root_namespace.find do |usage|
          usage.root_namespace_id == namespace2.id
        end.compute_minutes).to eq(200)
      end

      context 'when runner_id is specified' do
        subject(:per_root_namespace) { described_class.per_root_namespace(billing_month, nil, runner.id).to_a }

        it 'returns data only for the specified runner' do
          expect(per_root_namespace.count).to eq(1)
          expect(per_root_namespace.first.root_namespace_id).to eq(namespace1.id)
          expect(per_root_namespace.first.compute_minutes).to eq(100)
          expect(per_root_namespace.first.duration_seconds).to eq(6000)
        end
      end
    end
  end

  describe '.distinct_runner_ids' do
    let_it_be(:runner1) { create(:ci_runner) }
    let_it_be(:runner2) { create(:ci_runner) }

    before do
      create(:ci_hosted_runner_monthly_usage, runner: runner1)
      create(:ci_hosted_runner_monthly_usage, runner: runner1) # Duplicate usage for same runner
      create(:ci_hosted_runner_monthly_usage, runner: runner2)
    end

    it 'returns distinct runner IDs' do
      expect(described_class.distinct_runner_ids).to contain_exactly(runner1.id, runner2.id)
    end
  end

  describe '.distinct_years' do
    before do
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2023, 1, 1))
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2023, 2, 1)) # Same year
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2024, 1, 1))
    end

    it 'returns distinct years' do
      expect(described_class.distinct_years).to contain_exactly(2023, 2024)
    end

    it 'returns years in ascending order' do
      expect(described_class.distinct_years).to eq([2023, 2024])
    end
  end
end
