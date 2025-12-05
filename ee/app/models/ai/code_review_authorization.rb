# frozen_string_literal: true

module Ai
  class CodeReviewAuthorization
    def initialize(resource)
      @resource = resource
    end

    def allowed?(user)
      return false unless user

      use_duo_agent_platform?(user) || classic_flow_allowed?(user)
    end

    private

    attr_reader :resource

    def use_duo_agent_platform?(user)
      ::Ai::DuoWorkflows::CodeReview::AvailabilityValidator.new(
        user: user,
        resource: project_or_group
      ).available?
    end

    def classic_flow_allowed?(user)
      Ability.allowed?(user, :access_ai_review_mr, project_or_group) &&
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: project_or_group,
          feature_name: :review_merge_request,
          user: user
        ).allowed?
    end

    def project_or_group
      resource.is_a?(MergeRequest) ? resource.project : resource
    end
  end
end
