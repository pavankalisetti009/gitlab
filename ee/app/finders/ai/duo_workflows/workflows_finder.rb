# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowsFinder
      UnknownOptionError = Class.new(StandardError)

      # Identifies possible IDs in a search term:
      #   soft devel 123 -> 123
      #   soft devel #123 -> 123
      #   #123 soft devel -> 123
      #   soft devel v1 -> ""
      #   soft devel v12 #123 456 -> 123, 456
      SEARCH_IDS_PATTERN = /(?<=\s|^|[^\w])\d+/

      # Removes possible IDs from a search term:
      #   soft devel 123 -> soft devel
      #   soft devel #123 -> soft devel
      #   #123 soft devel -> soft devel
      #   soft devel v1 -> soft devel v1
      #   soft devel v12 #123 456 -> soft devel v12
      SEARCH_IDS_SANITIZER_PATTERN = /#?\s*(?<!\w)\d+\s*/

      class SortingCriteria
        SORTABLE_DIRECTIONS = %w[asc desc].freeze

        attr_reader :field, :direction

        def self.parse(criteria)
          *fields, direction = criteria.to_s.strip.downcase.split('_')

          unless direction.in?(SORTABLE_DIRECTIONS)
            fields << direction
            direction = SORTABLE_DIRECTIONS.first
          end

          new(fields.join("_"), direction)
        end

        def initialize(field, direction)
          @field = field
          @direction = direction
        end

        def to_s
          "#{field}_#{direction}"
        end
      end

      def initialize(options = {})
        @options = options.reverse_merge(default_options)
      end

      def results
        self.query = base_query

        options.each do |key, value|
          method_name = "resolve_#{key}"
          # rubocop:disable GitlabSecurity/PublicSend -- Method names don't come from user input
          self.query = public_send(method_name, value) if respond_to?(method_name) && resolvable?(value)
          # rubocop:enable GitlabSecurity/PublicSend
        end

        query
      end

      def base_query
        workflows = ::Ai::DuoWorkflows::Workflow

        current_user = option(:current_user)
        source = option(:source)

        return workflows.none unless current_user

        if source.is_a?(::Project)
          return workflows.none unless current_user.can?(:duo_workflow, source)

          workflows.for_project(source).from_pipeline
        elsif option?(:project_path)
          project = Project.find_by_full_path(option(:project_path))

          return workflows.none unless current_user.can?(:duo_workflow, project)

          workflows
            .for_user(current_user.id)
            .for_project(project)
        else
          workflows.for_user(current_user.id)
        end
      end

      def default_options
        {
          sort: "created_desc"
        }
      end

      def resolve_type(type)
        query.with_workflow_definition(type)
      end

      def resolve_exclude_types(exclude_types)
        query.without_workflow_definition(exclude_types)
      end

      def resolve_environment(environment)
        query.with_environment(environment)
      end

      def resolve_sort(sort)
        criteria = SortingCriteria.parse(sort)

        case criteria.field
        when "status"
          query.order_by_status(criteria.direction)
        else
          query.order_by(criteria.to_s)
        end
      end

      def resolve_search(term)
        possible_ids = term.scan(SEARCH_IDS_PATTERN).map(&:to_i)
        term_without_ids = term.gsub(SEARCH_IDS_SANITIZER_PATTERN, '').strip

        scope = query

        if term_without_ids.present?
          # We want to match things like `v1` so we set `use_minimum_char_limit = false`.
          scope = scope.fuzzy_search(term_without_ids, [:workflow_definition, :goal], use_minimum_char_limit: false)
        end

        if possible_ids.any?
          scope = scope.where(id: possible_ids) # rubocop:disable CodeReuse/ActiveRecord -- Finders should be allowed
        end

        scope
      end

      def resolve_status_group(status_group)
        query.in_status_group(status_group)
      end

      private

      attr_accessor :query

      attr_reader :options

      def resolvable?(value)
        case value
        when NilClass
          false
        when String, Array
          value.present?
        else
          true
        end
      end

      def option(name)
        options.fetch(name) { raise UnknownOptionError, name }
      end

      def option?(name)
        resolvable?(options[name])
      end
    end
  end
end
