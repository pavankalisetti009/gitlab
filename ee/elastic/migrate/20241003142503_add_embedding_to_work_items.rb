# frozen_string_literal: true

class AddEmbeddingToWorkItems < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  skip_if -> { !elasticsearch_8_plus? && !opensearch? }

  def index_name
    work_item_proxy.index_name
  end

  def new_mappings
    mappings = if elasticsearch_8_plus?
                 work_item_proxy.elasticsearch_8_plus_mappings
               else
                 work_item_proxy.opensearch_mappings
               end

    mappings.merge({ routing: { type: 'text' } })
  end
end

private

def elasticsearch_8_plus?
  helper.matching_distribution?(:elasticsearch, min_version: '8.0.0')
end

def opensearch?
  helper.matching_distribution?(:opensearch)
end

def helper
  @helper ||= Gitlab::Elastic::Helper.default
end

def work_item_proxy
  Search::Elastic::Types::WorkItem
end
