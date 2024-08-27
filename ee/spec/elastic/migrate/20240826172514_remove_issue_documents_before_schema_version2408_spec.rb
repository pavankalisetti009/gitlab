# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240826172514_remove_issue_documents_before_schema_version2408.rb')

RSpec.describe RemoveIssueDocumentsBeforeSchemaVersion2408, :elastic, :sidekiq_inline, feature_category: :global_search do
  include_examples 'migration deletes documents based on schema version' do
    let(:version) { 20240826172514 }

    let(:objects) { create_list(:issue, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 20000 }
  end
end
