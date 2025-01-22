# frozen_string_literal: true

module Dependencies
  class CreateExportService
    attr_reader :author, :exportable, :export_type

    def initialize(exportable, author, export_type = 'dependency_list')
      @exportable = exportable
      @author = author
      @export_type = export_type
    end

    def execute
      dependency_list_export = create_export

      if dependency_list_export.persisted?
        Dependencies::ExportWorker.perform_async(dependency_list_export.id)

        ServiceResponse.success(payload: { dependency_list_export: dependency_list_export })
      else
        ServiceResponse.error(message: dependency_list_export.errors.full_messages)
      end
    end

    private

    def create_export
      Dependencies::DependencyListExport.create(
        exportable: exportable,
        author: author,
        export_type: export_type
      )
    end
  end
end
