# frozen_string_literal: true

module Gitlab
  module LicenseScanning
    class PackageLicenses
      BATCH_SIZE = 700
      UNKNOWN_LICENSE = {
        spdx_identifier: "unknown",
        name: "unknown",
        url: nil
      }.freeze

      def initialize(components:, project: nil)
        @components = components
        # component_data keeps track of the requested versions for each component, to
        # facilitate faster lookups by avoiding an O(n^2) search against the components array
        @component_data = Hash.new { |h, k| h[k] = [] }
        @all_records = {}
        @project = project
      end

      def self.url_for(spdx_id)
        return if spdx_id.blank? || spdx_id == "unknown"

        "https://spdx.org/licenses/#{spdx_id}.html"
      end

      # obtains licenses by using data from the `licenses` jsonb column in the pm_packages table to query
      # data from the pm_licenses table
      def fetch
        use_replica_if_available do
          init_all_records_to_unknown_licenses do |component|
            # build cache for faster lookups of licenses and component_version data
            build_component_data_cache(component)
          end

          # For each batch of components, we execute two queries for components without license:
          #
          # 1. Retrieve the packages for the components by querying the pm_packages table
          # 2. Use the data in the `licenses` jsonb column of the pm_packages table to
          #    lookup the corresponding licenses. This query is executed by the
          #    `package.licenses_for` method.
          components.each_slice(BATCH_SIZE).each do |components_batch|
            if project && Feature.enabled?(:license_scanning_with_sbom_licenses, project)
              components_with_licenses, components_without_licenses = components_batch.partition do |c|
                c.licenses.present?
              end

              add_components_with_license(components_with_licenses)
              add_components_without_licenses(components_without_licenses)
            else
              add_components_without_licenses(components_batch)
            end
          end

          all_records.values
        end
      end

      private

      attr_reader :components, :component_data, :all_records, :project

      def use_replica_if_available(&block)
        ::Gitlab::Database::LoadBalancing::Session.current.use_replicas_for_read_queries(&block)
      end

      # set the default license of all components to an unknown license.
      # If a license is eventually found for the component, we'll overwrite
      # the unknown entry with the valid license.
      # Initializing all records with an unknown license allows us to ensure
      # that the packages and licenses we return from the fetch method are the
      # same order as the components that were initially passed to the fetch
      # method. This allows callers to make assumptions about the ordering of
      # the data, which can simplify their code.
      def init_all_records_to_unknown_licenses
        components.each do |component|
          add_record_with_unknown_license(component)
          yield component if block_given?
        end
      end

      def add_record_with_unknown_license(component)
        key = component_key(name: component.name, version: component.version, purl_type: component.purl_type)

        all_records[key] =
          Hashie::Mash.new(
            purl_type: component.purl_type, name: component.name, version: component.version,
            licenses: [UNKNOWN_LICENSE], path: component.path || ''
          )
      end

      def component_key(name:, version:, purl_type:)
        "#{name}/#{version}/#{purl_type}"
      end

      # we fetch package details from the pm_packages table which only contains the
      # purl_type and name. We need a way to know which versions were requested for
      # each purl_type and name, so we use a hash to store this data for faster lookups.
      def build_component_data_cache(component)
        component_data[component_data_key(name: component.name, purl_type: component.purl_type)] <<
          { version: component.version, path: component.path }
      end

      def component_data_key(name:, purl_type:)
        "#{name}/#{purl_type}"
      end

      def add_components_without_licenses(components_without_licenses)
        packages_for_batch = ::PackageMetadata::Package.packages_for(components: components_without_licenses)

        packages_for_batch.each do |package|
          requested_data_for_package(package).each do |component|
            license_ids = package.license_ids_for(version: component[:version])

            add_record_with_known_licenses(purl_type: package.purl_type, name: package.name,
              version: component[:version], license_ids: license_ids, path: component[:path])
          end
        end
      end

      def requested_data_for_package(package)
        component_data[component_data_key(name: package.name, purl_type: package.purl_type)]
      end

      # Every time a license is encountered for a component, we record it.
      # This allows us to determine which components do not have licenses.
      # Adds a single record with known licenses. This method is used by both the
      # uncompressed and compressed queries.
      def add_record_with_known_licenses(purl_type:, name:, version:, license_ids:, path:)
        all_records[component_key(name: name, version: version, purl_type: purl_type)] =
          Hashie::Mash.new(
            purl_type: purl_type, name: name, version: version,
            licenses: licenses_with_names_for(license_ids: license_ids), path: path || ''
          )
      end

      def licenses_with_names_for(license_ids:)
        return [UNKNOWN_LICENSE] if license_ids.blank?

        license_ids.map do |license_id|
          spdx_id = spdx_id_for(license_id: license_id)

          {
            spdx_identifier: spdx_id,
            name: license_name_for(spdx_id: spdx_id),
            url: self.class.url_for(spdx_id)
          }
        end
      end

      # there's only about 500 licenses in the pm_licenses table, and the data doesn't change often, so we use
      # a cache to avoid a separate sql query every time we need to convert from license_id to spdx_identifier.
      def spdx_id_for(license_id:)
        @pm_licenses ||= ::PackageMetadata::License.all.to_h { |license| [license.id, license.spdx_identifier] }
        @pm_licenses[license_id]
      end

      # there's only about 500 _valid_ licenses in the software_licenses table, and the data doesn't change often,
      # so we use a cache to avoid a separate sql query every time we need to convert from spdx_identifier to
      # license name.
      def license_name_for(spdx_id:)
        @software_licenses ||= SoftwareLicense.spdx.to_h { |license| [license.spdx_identifier, license.name] }
        @software_licenses[spdx_id] || spdx_id
      end

      def add_components_with_license(components_with_licenses)
        components_with_licenses.each do |component|
          add_record_with_ingested_licenses(component)
        end
      end

      def add_record_with_ingested_licenses(component)
        all_records[component_key(name: component.name, version: component.version,
          purl_type: component.purl_type)] = Hashie::Mash.new(
            purl_type: component.purl_type, name: component.name, version: component.version,
            licenses: licenses_for_component(component), path: component.path || ''
          )
      end

      def licenses_for_component(component)
        component.licenses.map do |component_license|
          spdx_id = component_license.spdx_identifier

          {
            spdx_identifier: spdx_id,
            name: component_license.name || license_name_for(spdx_id: spdx_id),
            url: component_license.url || self.class.url_for(spdx_id)
          }
        end
      end
    end
  end
end
