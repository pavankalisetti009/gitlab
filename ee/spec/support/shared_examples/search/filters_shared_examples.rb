# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'does not modify the query_hash' do
  it 'does not add the filter to query_hash' do
    expect(subject).to eq(query_hash)
  end
end
