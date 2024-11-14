# frozen_string_literal: true

module Dependencies
  module ExportSerializers
    class OrganizationDependenciesService
      def initialize(export)
        @export = export
      end

      def filename
        "#{export.organization.to_param}_dependencies_#{Time.current.utc.strftime('%FT%H%M')}.csv"
      end

      def each
        yield header

        iterator.each_batch do |batch|
          build_list_for(batch).each do |occurrence|
            yield to_csv([
              occurrence.component_name,
              occurrence.version,
              occurrence.package_manager,
              occurrence.location[:blob_path]
            ])
          end
        end
      end

      private

      attr_reader :export

      def header
        to_csv(%w[Name Version Packager Location])
      end

      def iterator
        Gitlab::Pagination::Keyset::Iterator.new(scope: ::Sbom::Occurrence.order_by_id)
      end

      def build_list_for(batch)
        batch
          .with_source
          .with_version
          .with_project_namespace
      end

      def to_csv(row)
        CSV.generate_line(row, force_quotes: true)
      end
    end
  end
end
