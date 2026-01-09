# frozen_string_literal: true

ELASTICSEARCH_MIN_VERSION = '8.0.0'
OPENSEARCH_MIN_VERSION = '2.1.0'

RSpec.configure do |config|
  config.include ActiveContextHelpers, :active_context

  config.after(:all, :active_context) do
    # Only attempt cleanup if an adapter is available. When no search service is running
    # (e.g., local development without Elasticsearch/OpenSearch), skip cleanup gracefully.
    delete_active_context_indices! if ::ActiveContext.adapter.present?
  end

  config.around(:each, :active_context) do |example|
    ::ActiveContext::Adapter.reset

    skip_if_adapter_mismatch(example)

    run_active_context_migrations!

    example.run

    clear_active_context_data!
  ensure
    # Reset adapter cache after each example to prevent stale adapters from leaking
    # to subsequent tests or hooks. This is especially important when tests skip
    # (e.g., OpenSearch tests skipping in an Elasticsearch-only CI job), as the
    # after(:all) hook would otherwise use the wrong adapter.
    ::ActiveContext::Adapter.reset
  end

  private

  # Skip tests if the configured adapter doesn't match the test's expected adapter.
  # CI runs the same test suite against multiple adapters (Elasticsearch 8, Elasticsearch 9,
  # OpenSearch 1, OpenSearch 2, etc.) by reusing the ELASTIC_URL environment variable to point
  # to different services. This means all tests run against whatever adapter is configured in
  # the current CI job, regardless of which adapter they were written for.
  #
  # This method ensures tests only run against their intended adapter by
  # checking the adapter metadata tags and skipping if there's a mismatch.
  def skip_if_adapter_mismatch(example)
    if example.metadata[:elasticsearch_adapter]
      skip_if_not_elasticsearch
    elsif example.metadata[:opensearch_adapter]
      skip_if_not_opensearch
    end
  end

  def skip_if_not_elasticsearch
    unless elastic_helper.matching_distribution?(:elasticsearch)
      skip "Elasticsearch test requires Elasticsearch service running"
      return
    end

    # Active Context requires Elasticsearch 8.x+.
    return if elastic_helper.matching_distribution?(:elasticsearch, min_version: ELASTICSEARCH_MIN_VERSION)

    skip "Elasticsearch test requires Elasticsearch #{ELASTICSEARCH_MIN_VERSION}+ service running"
  end

  def skip_if_not_opensearch
    unless elastic_helper.matching_distribution?(:opensearch)
      skip "OpenSearch test requires OpenSearch service running"
      return
    end

    # Active Context requires OpenSearch 2.1.0+ which supports the lucene engine for vector search.
    return if elastic_helper.matching_distribution?(:opensearch, min_version: OPENSEARCH_MIN_VERSION)

    skip "OpenSearch test requires OpenSearch #{OPENSEARCH_MIN_VERSION}+ service running"
  end

  def elastic_helper
    Gitlab::Elastic::Helper.new(client: ActiveContext::Adapter.current.client.client)
  end
end
