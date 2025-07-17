# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250708194823_remove_notes_fields_from_work_items.rb')

RSpec.describe RemoveNotesFieldsFromWorkItems, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250708194823 }
  let(:expected_throttle_delay) { 1.minute }
  let(:objects) { create_list(:work_item, 6) }
  let(:index_name) { ::Search::Elastic::Types::WorkItem.index_name }

  context 'for notes field' do
    include_examples 'migration removes field' do
      let(:field) { :notes }
      let(:mapping) { { type: :text, index_options: 'positions', analyzer: :code_analyzer } }
      let(:value) { 'Test note content' }
    end
  end

  context 'for notes_internal field' do
    include_examples 'migration removes field' do
      let(:field) { :notes_internal }
      let(:mapping) { { type: :text, index_options: 'positions', analyzer: :code_analyzer } }
      let(:value) { 'Test internal note content' }
    end
  end
end
