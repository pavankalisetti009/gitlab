# frozen_string_literal: true

module Packages
  class CreateAuditEventsService < ::Packages::AuditEventsBaseService
    def initialize(packages, current_user: nil, event_name: 'package_registry_package_deleted')
      @packages = packages
      @current_user = current_user
      @event_name = event_name
    end

    def execute
      super do
        ::Gitlab::Audit::Auditor.audit(initial_audit_context) do
          preload_groups
          packages.each { |pkg| send_event(pkg) }
        end
      end
    end

    private

    attr_reader :packages, :current_user, :event_name

    def initial_audit_context
      {
        name: event_name,
        author: current_user || ::Gitlab::Audit::NullAuthor.new,
        scope: ::Group.new,
        target: ::Gitlab::Audit::NullTarget.new,
        additional_details: { auth_token_type: }
      }
    end

    def preload_groups
      ::Group
        .select(:id)
        .include_route
        .id_in(packages.map { |pkg| pkg.project.namespace_id })
        .index_by(&:id)
        .then do |groups|
          packages.each { |pkg| pkg.project.group = groups[pkg.project.namespace_id] }
        end
    end

    def send_event(package)
      package.run_after_commit_or_now do
        event = {
          scope: project.group || project,
          target: self,
          target_details: "#{project.full_path}/#{name}-#{version}",
          message: "#{package_type.humanize} package deleted"
        }
        push_audit_event(event, after_commit: false)
      end
    end
  end
end
