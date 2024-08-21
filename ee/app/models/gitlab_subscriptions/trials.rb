# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    def self.single_eligible_namespace?(eligible_namespaces)
      return false unless eligible_namespaces.any? # executes query and now relation is loaded

      eligible_namespaces.count == 1
    end
  end
end
