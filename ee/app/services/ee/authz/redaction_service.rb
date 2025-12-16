# frozen_string_literal: true

module EE
  module Authz
    module RedactionService
      extend ::Gitlab::Utils::Override

      EE_RESOURCE_CLASSES = {
        'epics' => ::Epic,
        'vulnerabilities' => ::Vulnerability
      }.freeze

      EE_PRELOAD_ASSOCIATIONS = {
        'epics' => [:group],
        'vulnerabilities' => [{ project: [:namespace, :project_feature, :group] }]
      }.freeze

      module ClassMethods
        extend ::Gitlab::Utils::Override

        override :supported_types
        def supported_types
          super + EE::Authz::RedactionService::EE_RESOURCE_CLASSES.keys
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend ClassMethods
      end

      private

      override :load_resources_for_type
      # rubocop:disable CodeReuse/ActiveRecord -- Batch loading with preloads for authorization checks
      def load_resources_for_type(type, ids)
        return super unless EE_RESOURCE_CLASSES.key?(type)
        return {} if ids.blank?

        klass = EE_RESOURCE_CLASSES[type]
        preloads = EE_PRELOAD_ASSOCIATIONS[type]
        relation = klass.where(id: ids)
        relation = relation.includes(*preloads) if preloads
        relation.index_by(&:id)
      end
      # rubocop:enable CodeReuse/ActiveRecord

      override :authorize_resources_of_type
      def authorize_resources_of_type(type, ids, loaded_resources)
        return super unless EE_RESOURCE_CLASSES.key?(type)
        return {} if ids.blank?

        ids.index_with do |id|
          resource = loaded_resources[id]

          next false if resource.nil?

          visible_result?(resource)
        end
      end
    end
  end
end
