# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project elastic search redactions work_item', feature_category: :global_search do
  context "when we have document_type as work_item" do
    before do
      stub_feature_flags(search_issues_uses_work_items_index: true)
    end

    it_behaves_like 'a redacted search results page', document_type: :work_item do
      let(:search_path) { project_path(public_restricted_project) }
    end
  end
end
