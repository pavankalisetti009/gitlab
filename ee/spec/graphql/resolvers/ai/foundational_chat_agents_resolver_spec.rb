# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FoundationalChatAgentsResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) { resolve(described_class, args: { project_id: nil, namespace_id: nil }).to_a }

    it 'returns a list of foundational chat agents sorted by id' do
      expect(resolved).to eq(resolved.sort_by(&:id))
      expect(resolved[0].name).to eq('GitLab Duo Agent')
    end
  end

  describe 'arguments' do
    subject(:arguments) { described_class.arguments }

    it 'accepts namespace_id and project_id' do
      expect(arguments).to include('namespaceId', 'projectId')
    end
  end
end
