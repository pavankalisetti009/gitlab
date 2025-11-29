# frozen_string_literal: true

module Vulnerabilities
  class BulkEsOperationService
    def initialize(relation, preload_associations: true)
      @relation = relation
      @preload_associations = preload_associations
    end

    def execute
      return unless block_given?

      return yield relation unless ::Search::Elastic::VulnerabilityIndexHelper.indexing_allowed?

      vulnerabilities = if preload_associations
                          preload(relation)
                        else
                          relation
                        end

      eligible_vulnerabilities = vulnerabilities.select(&:maintaining_elasticsearch?)

      yield relation

      ::Elastic::ProcessBookkeepingService.track!(*eligible_vulnerabilities)
    end

    private

    attr_reader :relation, :preload_associations

    def preload(relation)
      vulnerabilities = relation.dup

      vulnerabilities.load

      # Project preload for Vulnerability#elastic_reference method
      # Project.Namespace preload for Vulnerabilities::Read.generate_es_parent method,
      # which is in turn called in Vulnerability#elastic_reference method.
      associations = nil
      if vulnerabilities.first.is_a?(Vulnerability)
        associations = [project: [:namespace]]
      elsif vulnerabilities.first.is_a?(Vulnerabilities::Read)
        associations = [vulnerability: [project: [:namespace]]]
      end

      ActiveRecord::Associations::Preloader.new(
        records: vulnerabilities,
        associations: associations
      ).call

      # And finally preload root_ancestor for Vulnerabilities::Read.generate_es_parent method
      preloaded_namespaces = vulnerabilities.map { |record| record.project.namespace }
      ::Namespaces::Preloaders::NamespaceRootAncestorPreloader.new(preloaded_namespaces).execute

      vulnerabilities
    end
  end
end
