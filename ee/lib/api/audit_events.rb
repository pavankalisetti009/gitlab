# frozen_string_literal: true

module API
  class AuditEvents < ::API::Base
    include ::API::PaginationParams

    urgency :low

    feature_category :audit_events

    before do
      authenticated_as_admin!
      forbidden! unless ::License.feature_available?(:admin_audit_log)
      increment_unique_values('a_compliance_audit_events_api', current_user.id)

      ::Gitlab::Tracking.event(
        'API::AuditEvents',
        :admin_audit_event_request,
        user: current_user,
        context: [::Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: 'a_compliance_audit_events_api').to_context]
      )
    end

    helpers do
      def use_new_audit_tables?
        Feature.enabled?(:read_audit_events_from_new_tables, current_user)
      end
    end

    resources :audit_events do
      desc 'Get the list of audit events' do
        success EE::API::Entities::AuditEvent
        is_array true
      end
      params do
        optional :entity_type, type: String, desc: 'Return audit events for the specified entity type', values: AuditEventFinder::VALID_ENTITY_TYPES
        optional :entity_id, type: Integer, desc: 'Return audit events for the specified entity ID. If defined, the request must also include the `entity_type` attribute.'
        given :entity_id do
          requires :entity_type, type: String
        end
        optional :created_after,
          type: DateTime,
          desc: 'Return audit events created after the specified time',
          documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }
        optional :created_before,
          type: DateTime,
          desc: 'Return audit events created before the specified time',
          documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }

        use :pagination
      end
      get do
        if use_new_audit_tables?
          finder_params = params.merge(pagination: params[:pagination] || 'offset')
          finder = ::AuditEvents::CombinedAuditEventFinder.new(params: finder_params)
          result = finder.execute

          if params[:pagination] == 'keyset'
            if result[:cursor_for_next_page]
              Gitlab::Pagination::Keyset::HeaderBuilder
                .new(self)
                .add_next_page_header({ cursor: result[:cursor_for_next_page] })
            end
          else
            current_page = result[:page]
            per_page = result[:per_page]

            next_page = result[:records].size == per_page ? current_page + 1 : nil
            prev_page = current_page > 1 ? current_page - 1 : nil

            Gitlab::Pagination::OffsetHeaderBuilder.new(
              request_context: self,
              per_page: per_page,
              page: current_page,
              next_page: next_page,
              prev_page: prev_page
            ).execute(data_without_counts: true)
          end

          present result[:records], with: EE::API::Entities::AuditEvent
        else
          level = ::Gitlab::Audit::Levels::Instance.new
          params[:optimize_offset] = true
          audit_events = AuditEventFinder.new(level: level, params: params).execute
          present paginate_with_strategies(audit_events), with: EE::API::Entities::AuditEvent
        end
      end

      desc 'Get single audit event' do
        success EE::API::Entities::AuditEvent
      end
      params do
        requires :id, type: Integer, desc: 'The ID of audit event'
      end
      get ':id' do
        audit_event = if use_new_audit_tables?
                        ::AuditEvents::CombinedAuditEventFinder.new.find(params[:id])
                      else
                        level = ::Gitlab::Audit::Levels::Instance.new
                        AuditEventFinder.new(level: level).find(params[:id])
                      end

        present audit_event, with: EE::API::Entities::AuditEvent
      end
    end
  end
end
