# frozen_string_literal: true

module Vulnerabilities
  class BulkDismissService < BaseBulkUpdateService
    def initialize(current_user, vulnerability_ids, comment, dismissal_reason)
      super(current_user, vulnerability_ids, comment)
      @dismissal_reason = dismissal_reason
    end

    private

    attr_reader :dismissal_reason

    def update(vulnerabilities_ids)
      selected_vulnerabilities = vulnerabilities_to_update(vulnerabilities_ids)
      vulnerability_attrs = vulnerabilities_attributes(selected_vulnerabilities)
      return if vulnerability_attrs.empty?

      db_attributes = db_attributes_for(vulnerability_attrs)
      projects = selected_vulnerabilities.with_projects.map(&:project).uniq

      SecApplicationRecord.transaction do
        update_support_tables(selected_vulnerabilities, db_attributes, projects)
        selected_vulnerabilities.update_all(db_attributes[:vulnerabilities])
      end

      attrs = vulnerability_attrs.map do |id, _, project_id, namespace_id|
        {
          vulnerability_id: id,
          project_id: project_id,
          namespace_id: namespace_id,
          dismissal_reason: dismissal_reason.to_s,
          comment: comment,
          user_id: user.id
        }
      end

      Gitlab::EventStore.publish(::Vulnerabilities::BulkDismissedEvent.new(data: { vulnerabilities: attrs }))
    end

    def vulnerabilities_to_update(ids)
      Vulnerability.id_in(ids)
    end

    def update_support_tables(vulnerabilities, db_attributes, project)
      Vulnerabilities::StateTransition.insert_all!(db_attributes[:state_transitions])

      Vulnerabilities::Reads::UpsertService.new(vulnerabilities, { dismissal_reason: dismissal_reason },
        projects: project).execute
    end

    def vulnerabilities_attributes(vulnerabilities)
      vulnerabilities
        .select(:id, :state, :project_id).with_projects
        .map { |v| [v.id, v.state, v.project_id, v.project.project_namespace_id] }
    end

    def db_attributes_for(vulnerability_attrs)
      {
        vulnerabilities: vulnerabilities_update_attributes,
        system_notes: system_note_attributes_for(vulnerability_attrs),
        state_transitions: transition_attributes_for(vulnerability_attrs)
      }
    end

    def vulnerabilities_update_attributes
      {
        state: :dismissed,
        auto_resolved: false,
        dismissed_by_id: user.id,
        dismissed_at: now,
        updated_at: now,
        confirmed_at: nil,
        confirmed_by_id: nil,
        resolved_at: nil,
        resolved_by_id: nil
      }
    end

    def transition_attributes_for(vulnerability_attrs)
      vulnerability_attrs.map do |id, state, _, _|
        {
          vulnerability_id: id,
          from_state: state,
          to_state: :dismissed,
          comment: comment,
          dismissal_reason: dismissal_reason,
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def system_note_attributes_for(vulnerability_attrs)
      vulnerability_attrs.map do |id, _, project_id, namespace_id|
        {
          noteable_type: "Vulnerability",
          noteable_id: id,
          project_id: project_id,
          namespace_id: namespace_id,
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            :dismissed,
            dismissal_reason.to_s.titleize,
            comment
          ),
          author_id: user.id,
          created_at: now,
          updated_at: now,
          discussion_id: Discussion.discussion_id(Note.new({
            noteable_id: id,
            noteable_type: "Vulnerability"
          }))
        }
      end
    end

    def system_note_metadata_attributes_for(results)
      results.map do |row|
        id = row['id']
        {
          note_id: id,
          action: system_note_metadata_action,
          created_at: now,
          updated_at: now
        }
      end
    end

    def system_note_metadata_action
      'vulnerability_dismissed'
    end
  end
end
