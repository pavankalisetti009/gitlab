# frozen_string_literal: true

module Projects
  class AiFeatures
    attr_accessor :project

    def initialize(project)
      @project = project
    end

    def review_merge_request_allowed?(user)
      ::Feature.enabled?(:ai_review_merge_request, user) &&
        project.licensed_feature_available?(:ai_review_mr) &&
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: project,
          feature_name: :review_merge_request
        ).allowed?
    end
  end
end
