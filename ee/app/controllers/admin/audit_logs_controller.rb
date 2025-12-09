# frozen_string_literal: true

class Admin::AuditLogsController < Admin::ApplicationController
  include Gitlab::Utils::StrongMemoize
  include AuditEvents::EnforcesValidDateParams
  include AuditEvents::AuditEventsParams
  include AuditEvents::Sortable
  include AuditEvents::DateRange
  include Gitlab::Tracking
  include ProductAnalyticsTracking
  include GovernUsageTracking

  before_action :check_license_admin_audit_event_available!

  track_event :index,
    name: 'i_compliance_audit_events',
    action: 'visit_instance_compliance_audit_events',
    label: 'redis_hll_counters.compliance.compliance_total_unique_counts_monthly',
    destinations: [:redis_hll, :snowplow]

  track_govern_activity 'audit_events', :index

  feature_category :audit_events

  PER_PAGE = 25

  def index
    @is_last_page = if use_new_audit_tables? && events.total_count == 0
                      true # Handle empty results edge case: Kaminari's last_page? returns false when total_pages=0
                    else
                      events.last_page?
                    end

    @events = AuditEventSerializer.new.represent(events)
    @audit_event_definitions = Gitlab::Audit::Type::Definition.names_with_category

    @entity = case audit_events_params[:entity_type]
              when 'User'
                user_entity
              when 'Project'
                Project.find_by_id(audit_events_params[:entity_id])
              when 'Group'
                Namespace.find_by_id(audit_events_params[:entity_id])
              end

    Gitlab::Tracking.event(self.class.name, 'search_audit_event', user: current_user)
  end

  def additional_properties_for_tracking
    return {} unless instance_active_frameworks?

    { with_active_compliance_frameworks: 'true' }
  end

  private

  def instance_active_frameworks?
    ::ComplianceManagement::ComplianceFramework::ProjectSettings.any?
  end

  def tracking_namespace_source
    nil
  end

  def tracking_project_source
    nil
  end

  def events
    strong_memoize(:events) do
      if use_new_audit_tables?
        finder_params = audit_events_params.merge(
          pagination: 'offset',
          page: pagination_params[:page],
          per_page: PER_PAGE
        )
        finder = ::AuditEvents::CombinedAuditEventFinder.new(params: finder_params)
        result = finder.execute

        events_array = Kaminari.paginate_array(
          result[:records],
          total_count: result[:total_count]
        ).page(result[:page]).per(result[:per_page])

        Gitlab::Audit::Events::Preloader.preload!(events_array)

        events_array
      else
        level = Gitlab::Audit::Levels::Instance.new
        events = AuditEventFinder
                   .new(level: level, params: audit_events_params)
                   .execute
                   .page(pagination_params[:page])
                   .per(PER_PAGE)
                   .without_count

        Gitlab::Audit::Events::Preloader.preload!(events)
      end
    end
  end

  def use_new_audit_tables?
    Feature.enabled?(:read_audit_events_from_new_tables, current_user)
  end

  def check_license_admin_audit_event_available!
    render_404 unless License.feature_available?(:admin_audit_log)
  end

  def user_entity
    if audit_events_params[:entity_username].present?
      return User.find_by_username(audit_events_params[:entity_username])
    end

    User.find_by_id(audit_events_params[:entity_id])
  end
end
