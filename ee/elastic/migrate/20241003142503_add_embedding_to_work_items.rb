# frozen_string_literal: true

class AddEmbeddingToWorkItems < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  skip_if -> { !elasticsearch_8_plus? }

  def index_name
    work_item_proxy.index_name
  end

  def new_mappings
    work_item_proxy.elasticsearch_8_plus_mappings.merge({ routing: { type: 'text' } })
  end
end

private

def elasticsearch_8_plus?
  helper.matching_distribution?(:elasticsearch, min_version: '8.0.0')
end

def helper
  @helper ||= Gitlab::Elastic::Helper.default
end

def work_item_proxy
  Search::Elastic::Types::WorkItem
end
