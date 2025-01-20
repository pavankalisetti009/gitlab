# frozen_string_literal: true

class InstanceSecurityDashboard
  extend ActiveModel::Naming
  include Gitlab::Utils::StrongMemoize

  delegate :full_path, to: :user
  delegate :root_ancestor, to: :duo_enabled_project, allow_nil: true

  attr_reader :user

  def initialize(user, project_ids: [])
    @project_ids = project_ids
    @user = user
  end

  def duo_features_enabled
    duo_enabled_project.present?
  end
  alias_method :duo_features_enabled?, :duo_features_enabled

  def feature_available?(feature)
    License.feature_available?(feature)
  end

  def non_archived_project_ids
    limit = UsersSecurityDashboardProject::SECURITY_DASHBOARD_PROJECTS_LIMIT
    projects.non_archived.limit(limit).pluck_primary_key
  end

  def projects
    Project.where(id: visible_users_security_dashboard_projects)
           .with_feature_available_for_user(:security_and_compliance, user)
           .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/485658')
  end

  def vulnerability_reads
    return Vulnerabilities::Read.none if projects.empty?

    Vulnerabilities::Read.for_projects(projects)
  end

  def vulnerability_scanners
    return Vulnerabilities::Scanner.none if projects.empty?

    Vulnerabilities::Scanner.for_projects(projects)
  end

  def vulnerability_historical_statistics
    return Vulnerabilities::HistoricalStatistic.none if projects.empty?

    Vulnerabilities::HistoricalStatistic.for_project(projects)
  end

  def has_projects?
    projects.count > 0
  end

  def cluster_agents
    return Clusters::Agent.none if projects.empty?

    Clusters::Agent.for_projects(projects)
  end

  private

  attr_reader :project_ids

  def duo_enabled_project
    projects
      .includes(:project_setting)
      .joins(:project_setting)
      .merge(ProjectSetting.duo_features_set(true))
      .first
  end
  strong_memoize_attr :duo_enabled_project

  def visible_users_security_dashboard_projects
    return users_security_dashboard_projects if user.can?(:read_all_resources)

    users_security_dashboard_projects.where('EXISTS(?)', project_authorizations)
  end

  def users_security_dashboard_projects
    UsersSecurityDashboardProject.select(:project_id).where(user: user)
  end

  def project_authorizations
    ProjectAuthorization
      .select(1)
      .where(users_security_dashboard_projects: { user_id: user.id })
      .where(project_authorizations: { user_id: user.id })
      .where('users_security_dashboard_projects.project_id = project_authorizations.project_id')
      .where(access_level: authorized_access_levels)
  end

  def authorized_access_levels
    Gitlab::Access.vulnerability_access_levels
  end
end
