# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::Aggregation::EngineResolver, feature_category: :value_stream_management do
  subject(:resolver) do
    Resolvers::Analytics::Aggregation::EngineResolver::BaseEngineResolver.new(object: nil,
      context: double.as_null_object, field: nil)
  end

  it 'requires aggregation_scope definition' do
    expect(resolver).to require_method_definition(:aggregation_scope)
  end
end
