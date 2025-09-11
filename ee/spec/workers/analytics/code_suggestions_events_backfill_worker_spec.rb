# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CodeSuggestionsEventsBackfillWorker, feature_category: :value_stream_management do
  it "does not raise error" do
    expect do
      described_class.new.perform('type', {})
    end.not_to raise_error
  end
end
