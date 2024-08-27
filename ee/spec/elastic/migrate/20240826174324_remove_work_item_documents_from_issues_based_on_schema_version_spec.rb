# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20240826174324_remove_work_item_documents_from_issues_based_on_schema_version.rb'
)

RSpec.describe RemoveWorkItemDocumentsFromIssuesBasedOnSchemaVersion, :elastic, :sidekiq_inline, feature_category: :global_search do
  let(:objects) { create_list(:work_item, 3) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    objects
    ensure_elasticsearch_index!
    update_by_query(objects, { source: "ctx._source.type='work_item'" })
  end

  include_examples 'migration deletes documents based on schema version' do
    let(:version) { 20240826174324 }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 20000 }
  end

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)
    client.update_by_query({
      index: migration.index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    })
  end
end
