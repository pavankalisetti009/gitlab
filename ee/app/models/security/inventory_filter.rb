# frozen_string_literal: true

module Security
  class InventoryFilter < ::SecApplicationRecord
    include ::Namespaces::Traversal::Traversable
    include Gitlab::SQL::Pattern

    self.table_name = 'security_inventory_filters'

    belongs_to :project
    validates :archived, allow_nil: false, inclusion: { in: [true, false] }

    # Analyzer statuses
    Enums::Security.extended_analyzer_types.each_key do |analyzer_type|
      enum analyzer_type.to_sym, Enums::Security.analyzer_statuses, prefix: true
      validates analyzer_type, presence: true
    end

    # vulnerability counts
    validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :critical, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :high, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :medium, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :low, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :info, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :unknown, presence: true, numericality: { greater_than_or_equal_to: 0 }

    validates :project_name, presence: true
    validates :traversal_ids, presence: true

    scope :by_project_id, ->(project_id) { where(project_id: project_id) }
    scope :order_by_project_id_asc, -> { order(project_id: :asc) }
    scope :unarchived, -> { where(archived: false) }
    scope :order_by_traversal_and_project, -> { order(traversal_ids: :asc, project_id: :asc) }
    scope :by_severity_count, ->(severity, operator, count) do
      return none unless Enums::Vulnerability.severity_levels.key?(severity)

      arel_column = arel_table[severity]
      case operator.to_s
      when 'greater_than_or_equal_to'
        where(arel_column.gteq(count))
      when 'less_than_or_equal_to'
        where(arel_column.lteq(count))
      when 'equal_to'
        where(arel_column.eq(count))
      else
        none
      end
    end
    scope :by_analyzer_status, ->(analyzer_type, status) do
      analyzer_type = analyzer_type.downcase.to_sym
      return none unless Enums::Security.extended_analyzer_types.key?(analyzer_type)

      where(arel_table[analyzer_type].eq(Enums::Security.analyzer_statuses[status.to_sym]))
    end

    scope :by_security_attributes, ->(is_one_of_filters, is_not_one_of_filters) do
      return none if is_one_of_filters.empty? && is_not_one_of_filters.empty?

      scope = all

      is_one_of_filters.each do |attribute_ids|
        sanitized_ids = attribute_ids.map(&:to_i)
        scope = scope.where(
          "EXISTS (
            SELECT 1 FROM project_to_security_attributes
            WHERE project_id = security_inventory_filters.project_id
            AND security_attribute_id = ANY(ARRAY[?])
          )", sanitized_ids
        )
      end

      is_not_one_of_filters.each do |attribute_ids|
        sanitized_ids = attribute_ids.map(&:to_i)
        scope = scope.where(
          "NOT EXISTS (
            SELECT 1 FROM project_to_security_attributes
            WHERE project_id = security_inventory_filters.project_id
            AND security_attribute_id = ANY(ARRAY[?])
          )", sanitized_ids
        )
      end

      scope
    end

    def self.search(query)
      fuzzy_search(query, [:project_name], use_minimum_char_limit: true)
    end
  end
end
