# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsageEvents::DumpWriteBufferCronWorker, feature_category: :database do
  let_it_be(:organization) { create(:organization) }
  let(:job) { described_class.new }
  let(:perform) { job.perform }

  let(:inserted_records) { Ai::CodeSuggestionEvent.all.map(&:attributes) }

  it 'does not insert anything' do
    perform

    expect(inserted_records).to be_empty
  end

  def add_to_buffer(attributes)
    data = { 'timestamp' => Time.current, 'organization_id' => organization.id }.merge(attributes.stringify_keys)
    Ai::UsageEventWriteBuffer.add(Ai::CodeSuggestionEvent.name, data)
  end

  context 'when data is present' do
    before do
      add_to_buffer(user_id: 1, event: 'code_suggestion_shown_in_ide')
      add_to_buffer(user_id: 2, event: 'code_suggestion_shown_in_ide')
      add_to_buffer(user_id: 3, event: 'code_suggestion_shown_in_ide', payload: { language: 'ruby' })
    end

    it 'inserts all rows' do
      status = perform

      expect(status).to eq({ status: :processed, inserted_rows: 3 })
      expect(inserted_records).to match([
        hash_including('user_id' => 1, 'event' => 'code_suggestion_shown_in_ide'),
        hash_including('user_id' => 2, 'event' => 'code_suggestion_shown_in_ide'),
        hash_including('user_id' => 3, 'event' => 'code_suggestion_shown_in_ide',
          'payload' => { 'language' => 'ruby' })
      ])
    end

    context 'when looping twice' do
      it 'inserts all rows' do
        stub_const("#{described_class.name}::BATCH_SIZE", 2)

        expect(perform).to eq({ status: :processed, inserted_rows: 3 })
      end
    end

    context 'when time limit is up' do
      it 'returns over_time status' do
        stub_const("#{described_class.name}::BATCH_SIZE", 1)

        allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
          allow(limiter).to receive(:over_time?).and_return(false, false, true)
        end

        status = perform

        expect(status).to eq({ status: :over_time, inserted_rows: 2 })
        expect(inserted_records).to match([
          hash_including('user_id' => 1),
          hash_including('user_id' => 2)
        ])
      end
    end
  end
end
