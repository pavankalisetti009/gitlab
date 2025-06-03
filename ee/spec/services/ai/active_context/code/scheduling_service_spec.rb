# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::SchedulingService, feature_category: :global_search do
  describe '#execute' do
    let(:redis_throttle) { class_spy(Gitlab::Utils::RedisThrottle) }
    let(:tasks) { { example_task: { dispatch: { event: TestEvent } } } }
    let(:event_class) do
      Class.new(::Gitlab::EventStore::Event) do
        def schema
          {
            'type' => 'object',
            'properties' => {},
            'additionalProperties' => false
          }
        end
      end
    end

    subject(:execute) { described_class.new(:example_task).execute }

    before do
      stub_const('TestEvent', event_class)
      stub_const("#{described_class}::TASKS", tasks)
      allow(Gitlab::EventStore).to receive(:publish)
      allow(Gitlab::Utils::RedisThrottle).to receive(:execute_every).and_yield
    end

    context 'with valid task' do
      it 'publishes an event to the event store' do
        execute

        expect(Gitlab::EventStore).to have_received(:publish).with(an_instance_of(TestEvent))
      end

      it 'uses RedisThrottle.execute_every with the correct cache key' do
        expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:-:example_task'

        execute

        expect(Gitlab::Utils::RedisThrottle).to have_received(:execute_every).with(nil, expected_cache_key)
      end
    end

    context 'with periodic task' do
      let(:tasks) { { example_task: { period: 5.minutes, dispatch: { event: TestEvent } } } }

      it 'uses RedisThrottle.execute_every with the correct period and cache key' do
        expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:300:example_task'

        execute

        expect(Gitlab::Utils::RedisThrottle).to have_received(:execute_every).with(
          5.minutes, expected_cache_key
        )
      end
    end

    context 'with conditional task' do
      context 'when condition is true' do
        let(:tasks) { { example_task: { if: -> { true }, dispatch: { event: TestEvent } } } }

        it 'publishes the event' do
          execute

          expect(Gitlab::EventStore).to have_received(:publish)
        end
      end

      context 'when condition is false' do
        let(:tasks) { { example_task: { if: -> { false }, dispatch: { event: TestEvent } } } }

        it 'does not publish the event' do
          execute

          expect(Gitlab::EventStore).not_to have_received(:publish)
        end
      end
    end

    context 'with execute block' do
      let(:tasks) do
        {
          example_task: {
            execute: -> { true }
          }
        }
      end

      it 'executes the provided block' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:instance_exec).once
        end

        execute
      end
    end

    context 'with invalid task' do
      it 'raises ArgumentError for unknown task' do
        service = described_class.new(:unknown_task)

        expect { service.execute }.to raise_error(ArgumentError, 'Unknown task: :unknown_task')
      end

      context 'without execute or dispatch' do
        let(:tasks) { { example_task: { if: -> { true } } } }

        it 'raises NotImplementedError' do
          message = 'No execute block or dispatch defined for task example_task'
          expect { execute }.to raise_error(NotImplementedError, message)
        end
      end
    end
  end

  describe '#cache_period' do
    let(:service) { described_class.new(:example_task) }

    context 'when task has a period' do
      before do
        stub_const("#{described_class}::TASKS", { example_task: { period: 5.minutes } })
      end

      it 'returns the period from the task config' do
        expect(service.cache_period).to eq(5.minutes)
      end
    end

    context 'when task has no period' do
      before do
        stub_const("#{described_class}::TASKS", { example_task: {} })
      end

      it 'returns nil' do
        expect(service.cache_period).to be_nil
      end
    end

    context 'when task does not exist' do
      before do
        stub_const("#{described_class}::TASKS", {})
      end

      it 'returns nil' do
        expect(service.cache_period).to be_nil
      end
    end
  end

  describe '#cache_key_for_period' do
    let(:service) { described_class.new(:example_task) }

    it 'generates a correct cache key with nil period' do
      expect(service.send(:cache_key_for_period, nil))
        .to eq('ai/active_context/code/scheduling_service:execute_every:-:example_task')
    end

    it 'generates a correct cache key with a period' do
      expected_cache_key = 'ai/active_context/code/scheduling_service:execute_every:300:example_task'
      expect(service.send(:cache_key_for_period, 5.minutes)).to eq(expected_cache_key)
    end
  end
end
