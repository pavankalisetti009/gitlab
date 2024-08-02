# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::MergeRequestDependency, feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:other_merge_request) { create(:merge_request) }

  let_it_be(:block) do
    merge_request.blocks_as_blockee.create!(blocking_merge_request: other_merge_request)
  end

  let_it_be(:entity) { described_class.new(merge_request.blocks_as_blockee.first) }

  subject(:entity_json) { entity.as_json }

  it "returns expected data" do
    aggregate_failures do
      expect(entity_json[:id]).to eq(block.id)
      expect(entity_json[:blocked_merge_request][:id]).to eq(block.blocked_merge_request.id)
      expect(entity_json[:blocking_merge_request][:id]).to eq(block.blocking_merge_request.id)
      expect(entity_json[:project_id]).to eq(block.blocking_merge_request.project_id)
    end
  end
end
