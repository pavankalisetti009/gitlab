# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ai::ActiveContext integration', :clean_gitlab_redis_shared_state, :sidekiq_inline,
  feature_category: :global_search do
  let(:shard) { 0 }
  let(:identifier_success) { 'hash_success' }
  let(:identifier_fail) { 'hash_fail' }
  let(:routing) { 1 }

  let_it_be(:collection) do
    create(
      :ai_active_context_collection,
      :code_embeddings_with_versions,
      include_ref_fields: false
    )
  end

  let(:successful_ref) do
    Ai::ActiveContext::References::Code.serialize(
      collection_id: collection.id,
      routing: routing,
      data: { id: identifier_success }
    )
  end

  let(:failing_ref) do
    Ai::ActiveContext::References::Code.serialize(
      collection_id: collection.id,
      routing: routing,
      data: { id: identifier_fail }
    )
  end

  before do
    allow(ActiveContext).to receive(:indexing?).and_return(true)
    allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(false)
    allow(::Ai::ActiveContext).to receive(:paused?).and_return(false)

    bulk_processor = instance_double(ActiveContext::BulkProcessor)
    allow(ActiveContext::BulkProcessor).to receive(:new).and_return(bulk_processor)
    allow(bulk_processor).to receive(:process)
    allow(bulk_processor).to receive(:flush).and_return([])

    Ai::ActiveContext::Queues::Code.clear_tracking!
    ActiveContext::RetryQueue.clear_tracking!
    ActiveContext::DeadQueue.clear_tracking!
  end

  describe 'successful processing' do
    it 'processes code refs from the queue successfully' do
      search_response = [{ 'id' => identifier_success, 'content' => 'test content' }]
      allow(::ActiveContext).to receive_message_chain(:adapter, :client, :search).and_return(search_response)
      allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(:generate_embeddings)
        .and_return([[1, 2, 3]])

      Ai::ActiveContext::Queues::Code.push([successful_ref])

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(1)
      expect(ActiveContext::RetryQueue.queue_size).to eq(0)
      expect(ActiveContext::DeadQueue.queue_size).to eq(0)

      Ai::ActiveContext::BulkProcessWorker.perform_async('Ai::ActiveContext::Queues::Code', shard)

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(0)
      expect(ActiveContext::RetryQueue.queue_size).to eq(0)
      expect(ActiveContext::DeadQueue.queue_size).to eq(0)
    end
  end

  describe 'failure and retry flow' do
    it 'moves failed refs to retry queue, then to dead queue on second failure' do
      Ai::ActiveContext::Queues::Code.push([failing_ref])

      allow(::ActiveContext).to receive_message_chain(:adapter, :client, :search)
        .and_return([{ 'id' => identifier_fail, 'content' => 'test content' }])
      allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(:generate_embeddings)
        .and_raise(StandardError, 'Embeddings generation failed')

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(1)
      expect(ActiveContext::RetryQueue.queue_size).to eq(0)
      expect(ActiveContext::DeadQueue.queue_size).to eq(0)

      expect(::ActiveContext::Logger).to receive(:retryable_exception)
      Ai::ActiveContext::BulkProcessWorker.perform_async('Ai::ActiveContext::Queues::Code', shard)

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(0)
      expect(ActiveContext::RetryQueue.queue_size).to eq(1)
      expect(ActiveContext::DeadQueue.queue_size).to eq(0)

      expect(::ActiveContext::Logger).to receive(:retryable_exception)
      Ai::ActiveContext::BulkProcessWorker.perform_async('ActiveContext::RetryQueue', shard)

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(0)
      expect(ActiveContext::RetryQueue.queue_size).to eq(0)
      expect(ActiveContext::DeadQueue.queue_size).to eq(1)
    end
  end

  describe 'dead queue is not processed' do
    it 'does not process items from the dead queue' do
      ActiveContext::DeadQueue.push([failing_ref])

      expect(ActiveContext::DeadQueue.queue_size).to eq(1)

      Ai::ActiveContext::BulkProcessWorker.perform_async

      expect(ActiveContext::DeadQueue.queue_size).to eq(1)
    end

    it 'dead queue is not included in raw_queues' do
      raw_queues = ActiveContext.raw_queues

      expect(raw_queues.map(&:class)).not_to include(ActiveContext::DeadQueue)
      expect(raw_queues.map(&:class)).to include(ActiveContext::RetryQueue)
    end
  end

  describe 'multiple failures and successes' do
    it 'handles mixed success and failure scenarios correctly' do
      Ai::ActiveContext::Queues::Code.push([successful_ref, failing_ref])

      # Only return content for the successful ref to simulate missing content failure
      search_response = [
        { 'id' => identifier_success, 'content' => 'success content' }
      ]
      allow(::ActiveContext).to receive_message_chain(:adapter, :client, :search).and_return(search_response)

      allow(Ai::ActiveContext::Embeddings::Code::VertexText).to receive(:generate_embeddings)
        .with(['success content'], anything)
        .and_return([[1, 2, 3]])

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(2)

      expect(::ActiveContext::Logger).to receive(:retryable_exception)
      Ai::ActiveContext::BulkProcessWorker.perform_async('Ai::ActiveContext::Queues::Code', shard)

      expect(Ai::ActiveContext::Queues::Code.queue_size).to eq(0)
      expect(ActiveContext::RetryQueue.queue_size).to eq(1)
      expect(ActiveContext::DeadQueue.queue_size).to eq(0)

      expect(::ActiveContext::Logger).to receive(:retryable_exception)
      Ai::ActiveContext::BulkProcessWorker.perform_async('ActiveContext::RetryQueue', shard)

      expect(ActiveContext::RetryQueue.queue_size).to eq(0)
      expect(ActiveContext::DeadQueue.queue_size).to eq(1)
    end
  end
end
