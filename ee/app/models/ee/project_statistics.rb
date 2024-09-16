# frozen_string_literal: true

module EE
  module ProjectStatistics
    extend ::Gitlab::Utils::Override

    def cost_factored_storage_size
      (storage_size * cost_factor).round
    end

    def cost_factored_repository_size
      (repository_size * cost_factor).round
    end

    def cost_factored_build_artifacts_size
      (build_artifacts_size * cost_factor).round
    end

    def cost_factored_lfs_objects_size
      (lfs_objects_size * cost_factor).round
    end

    def cost_factored_packages_size
      (packages_size * cost_factor).round
    end

    def cost_factored_snippets_size
      (snippets_size * cost_factor).round
    end

    def cost_factored_wiki_size
      (wiki_size * cost_factor).round
    end

    def increase_vulnerability_counter!(increment)
      self.class.id_in(id).update_all("vulnerability_count = vulnerability_count + #{increment}")
    end

    def decrease_vulnerability_counter!(decrement)
      self.class.id_in(id).update_all("vulnerability_count = vulnerability_count - #{decrement}")
    end

    private

    def cost_factor
      ::Namespaces::Storage::CostFactor.cost_factor_for(project)
    end

    override :storage_size_components
    def storage_size_components
      if ::Gitlab::CurrentSettings.should_check_namespace_plan?
        self.class::STORAGE_SIZE_COMPONENTS - [:uploads_size]
      else
        super
      end
    end
  end
end
