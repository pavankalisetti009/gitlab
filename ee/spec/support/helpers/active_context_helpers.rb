# frozen_string_literal: true

module ActiveContextHelpers
  TEST_INDEX_PREFIX = 'gitlab_active_context_test'

  module_function

  def code_collection_name
    "#{TEST_INDEX_PREFIX}_code"
  end

  def run_active_context_migrations!
    dictionary = ActiveContext::Migration::Dictionary.instance

    dictionary.migrations.each do |migration_class|
      migration_instance = migration_class.new
      migration_instance.migrate!
    end
  end

  def delete_active_context_indices!
    active_context_indices.each do |index_name|
      active_context_client.indices.delete(index: index_name)
    end
  end

  def clear_active_context_data!
    active_context_client.delete_by_query(
      index: "#{TEST_INDEX_PREFIX}_*",
      body: { query: { match_all: {} } },
      conflicts: 'proceed'
    )
  end

  def refresh_active_context_indices!
    active_context_client.indices.refresh(index: "#{TEST_INDEX_PREFIX}_*")
  end

  def get_active_context_mappings(index)
    active_context_client.indices.get_mapping(index: index).each_value.first['mappings']['properties']
  end

  private

  def active_context_client
    ::ActiveContext.adapter.client.client
  end

  def active_context_indices
    response = active_context_client.cat.indices(format: 'json')
    response.select { |index| index['index'].start_with?(TEST_INDEX_PREFIX) }.pluck('index')
  end
end
