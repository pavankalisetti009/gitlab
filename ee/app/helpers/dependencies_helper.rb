# frozen_string_literal: true

module DependenciesHelper
  def project_dependencies_data(project)
    pipeline = project.latest_ingested_sbom_pipeline

    shared_dependencies_data.merge({
      has_dependencies: project.has_dependencies?.to_s,
      endpoint: project_dependencies_path(project, format: :json),
      export_endpoint: expose_path(api_v4_projects_dependency_list_exports_path(id: project.id)),
      vulnerabilities_endpoint: expose_path(api_v4_occurrences_vulnerabilities_path),
      sbom_reports_errors: sbom_report_ingestion_errors(pipeline).to_json,
      latest_successful_scan_path: (project_pipeline_path(project, pipeline) if pipeline),
      scan_finished_at: pipeline&.finished_at
    })
  end

  def group_dependencies_data(group, below_group_limit)
    shared_dependencies_data.merge({
      has_dependencies: group.has_dependencies?.to_s,
      endpoint: group_dependencies_path(group, format: :json),
      licenses_endpoint: licenses_group_dependencies_path(group),
      locations_endpoint: locations_group_dependencies_path(group),
      export_endpoint: expose_path(api_v4_groups_dependency_list_exports_path(id: group.id)),
      vulnerabilities_endpoint: expose_path(api_v4_occurrences_vulnerabilities_path),
      below_group_limit: below_group_limit.to_s
    })
  end

  def explore_dependencies_data(organization, page_info)
    shared_dependencies_data.merge({
      has_dependencies: organization.has_dependencies?.to_s,
      page_info: page_info,
      endpoint: explore_dependencies_path(format: :json),
      licenses_endpoint: nil,
      locations_endpoint: nil,
      export_endpoint: expose_path(api_v4_organizations_dependency_list_exports_path(id: organization.id)),
      vulnerabilities_endpoint: nil,
      below_group_limit: 'false'
    })
  end

  private

  def shared_dependencies_data
    {
      documentation_path: help_page_path('user/application_security/dependency_list/index'),
      empty_state_svg_path: image_path('illustrations/empty-state/empty-radar-md.svg')
    }
  end

  def sbom_report_ingestion_errors(pipeline)
    pipeline&.sbom_report_ingestion_errors || []
  end
end
