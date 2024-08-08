# frozen_string_literal: true

module Projects
  class DependenciesController < Projects::ApplicationController
    include SecurityAndCompliancePermissions
    include GovernUsageProjectTracking

    before_action :authorize_read_dependency_list!

    feature_category :dependency_management
    urgency :low
    track_govern_activity 'dependencies', :index

    def index
      respond_to do |format|
        format.html do
          render status: :ok
        end
        format.json do
          render json: serializer.represent(dependencies)
        end
      end
    end

    private

    def collect_dependencies
      dependencies_finder.execute
        .with_component
        .with_version
        .with_source
    end

    def authorize_read_dependency_list!
      render_not_authorized unless can?(current_user, :read_dependency, project)
    end

    def dependencies
      @dependencies ||= collect_dependencies
    end

    def dependency_list_params
      params.permit(:sort_by, :sort, :filter, :page, :per_page, source_types: []).with_defaults(
        source_types: default_source_type_filters)
    end

    def default_source_type_filters
      ::Sbom::Source::DEFAULT_SOURCES.keys + [nil]
    end

    def serializer
      ::DependencyListSerializer.new(project: project, user: current_user).with_pagination(request, response)
    end

    def dependencies_finder
      ::Sbom::DependenciesFinder.new(project, params: dependency_list_params)
    end

    def render_not_authorized
      respond_to do |format|
        format.html do
          render_404
        end
        format.json do
          render_403
        end
      end
    end
  end
end
