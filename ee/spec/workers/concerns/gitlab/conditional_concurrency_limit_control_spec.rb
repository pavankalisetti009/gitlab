# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::ConditionalConcurrencyLimitControl, feature_category: :shared do
  let(:defer_job) { false }

  let(:worker_class) do
    Class.new do
      prepend ::Gitlab::ConditionalConcurrencyLimitControl
      def perform(_defer_job)
        puts 'Perform Job'
      end

      def defer_job?(*args)
        args.first
      end
    end
  end

  subject(:perform) { worker_class.new.perform(defer_job) }

  context 'when defer_job? returns true' do
    let(:defer_job) { true }

    it 'reschedule the worker' do
      expect(worker_class).to receive(:perform_in).with(
        ::Gitlab::ConditionalConcurrencyLimitControl::DEFAULT_RESCHEDULE_INTERVAL, defer_job)

      perform
    end
  end

  context 'when defer_job? returns false' do
    it 'does not reschedule the work' do
      expect(worker_class).not_to receive(:perform_in).with(
        ::Gitlab::ConditionalConcurrencyLimitControl::DEFAULT_RESCHEDULE_INTERVAL, defer_job)

      expect_next_instance_of(worker_class) do |instance|
        expect(instance).to receive(:perform).with(defer_job)
      end

      perform
    end
  end

  context 'when defer_job? is not defined' do
    let(:worker_class) do
      Class.new do
        prepend ::Gitlab::ConditionalConcurrencyLimitControl
        def perform; end
      end
    end

    subject(:perform) { worker_class.new.perform }

    it 'does not reschedule the work' do
      expect(worker_class).not_to receive(:perform_in).with(
        ::Gitlab::ConditionalConcurrencyLimitControl::DEFAULT_RESCHEDULE_INTERVAL)

      perform
    end
  end
end
