# frozen_string_literal: true

module Sbom
  module Exporters
    class CsvService
      LIST_DELIMITER = '; '
      LIST_ROW_SEPARATOR = ''

      attr_reader :sbom_occurrences

      def initialize(_export, sbom_occurrences)
        @sbom_occurrences = sbom_occurrences
      end

      def generate(&block)
        csv_builder.render(&block)
      end

      def header
        CSV.generate_line(mapping.keys)
      end

      private

      def preloads
        [
          :source,
          :component_version,
          { project: [namespace: :route] },
          :vulnerabilities
        ]
      end

      def csv_builder
        @csv_builder ||= CsvBuilder.new(sbom_occurrences, mapping, preloads,
          replace_newlines: true)
      end

      def mapping
        {
          s_('DependencyListExport|Name') => 'component_name',
          s_('DependencyListExport|Version') => 'version',
          s_('DependencyListExport|Packager') => 'package_manager',
          s_('DependencyListExport|Location') => ->(occurrence) { occurrence.location[:blob_path] },
          s_('DependencyListExport|License Identifiers') => ->(occurrence) {
            # rubocop:disable CodeReuse/ActiveRecord -- `licenses` is an array
            # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- `licenses` is an array
            serialize_list(occurrence.licenses.pluck('spdx_identifier'))
            # rubocop:enable CodeReuse/ActiveRecord
            # rubocop:enable Database/AvoidUsingPluckWithoutLimit
          },
          s_('DependencyListExport|Project') => ->(occurrence) { occurrence.project.full_path },
          s_('DependencyListExport|Vulnerabilities Detected') => 'vulnerability_count',
          s_('DependencyListExport|Vulnerability IDs') => ->(occurrence) {
            serialize_list(occurrence.vulnerabilities.map(&:id))
          }
        }
      end

      def serialize_list(list)
        list.to_csv(col_sep: LIST_DELIMITER, row_sep: LIST_ROW_SEPARATOR)
      end
    end
  end
end
