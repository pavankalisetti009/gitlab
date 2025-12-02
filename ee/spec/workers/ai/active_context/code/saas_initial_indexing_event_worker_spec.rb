# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::SaasInitialIndexingEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::SaasInitialIndexingEvent.new(data: {}) }

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  it 'does nothing' do
    expect(execute).to eq([{}])
  end
end
