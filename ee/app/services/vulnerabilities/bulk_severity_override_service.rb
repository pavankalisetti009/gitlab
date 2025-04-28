# frozen_string_literal: true

module Vulnerabilities
  class BulkSeverityOverrideService < BaseBulkUpdateService
    def initialize(current_user, vulnerability_ids, comment, severity)
      super(current_user, vulnerability_ids, comment)
      @new_severity = severity
    end

    private

    def update(vulnerabilities_ids)
      vulnerabilities = vulnerabilities_to_update(vulnerabilities_ids)
      vulnerability_attrs = vulnerabilities_attributes(vulnerabilities)
      return if vulnerability_attrs.empty?

      db_attributes = db_attributes_for(vulnerability_attrs)

      SecApplicationRecord.transaction do
        update_support_tables(vulnerabilities, db_attributes)
        vulnerabilities.update_all(db_attributes[:vulnerabilities])
      end

      Note.transaction do
        notes_ids = Note.insert_all!(db_attributes[:system_notes], returning: %w[id])
        SystemNoteMetadata.insert_all!(system_note_metadata_attributes_for(notes_ids))
      end

      audit_severity_changes(vulnerability_attrs)
    end

    def authorized_for_project(project)
      super && Feature.enabled?(:vulnerability_severity_override, project.root_ancestor)
    end

    def severity_overrides_attributes_for(vulnerability_attrs)
      vulnerability_attrs.map do |id, severity, project_id|
        {
          vulnerability_id: id,
          original_severity: severity,
          new_severity: @new_severity,
          project_id: project_id,
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def audit_severity_changes(vulnerability_attrs)
      vulnerabilities_audit_attrs = vulnerability_attrs.map do |_, severity, _, _, project, vulnerability|
        {
          old_severity: severity,
          project: project,
          vulnerability: vulnerability
        }
      end

      SeverityOverrideAuditService.new(
        vulnerabilities_audit_attrs: vulnerabilities_audit_attrs,
        now: now,
        current_user: user,
        new_severity: @new_severity
      ).execute
    end

    def db_attributes_for(vulnerability_attrs)
      {
        vulnerabilities: vulnerabilities_update_attributes,
        severity_overrides: severity_overrides_attributes_for(vulnerability_attrs),
        system_notes: system_note_attributes_for(vulnerability_attrs)
      }
    end

    def vulnerabilities_to_update(ids)
      # rubocop: disable CodeReuse/ActiveRecord -- context specific
      Vulnerability.id_in(ids).where.not(severity: @new_severity)
      # rubocop: enable CodeReuse/ActiveRecord
    end

    def update_support_tables(vulnerabilities, db_attributes)
      Vulnerabilities::Finding.by_vulnerability(vulnerabilities).update_all(severity: @new_severity, updated_at: now)
      Vulnerabilities::SeverityOverride.insert_all!(db_attributes[:severity_overrides])
    end

    def vulnerabilities_attributes(vulnerabilities)
      attributes_relation = vulnerabilities.select(:id, :severity, :project_id).with_projects
      attributes_relation.map { |v| [v.id, v.severity, v.project_id, v.project.project_namespace_id, v.project, v] }
    end

    def vulnerabilities_update_attributes
      {
        severity: @new_severity,
        updated_at: now
      }
    end

    def system_note_metadata_action
      "vulnerability_severity_changed"
    end

    def system_note_attributes_for(vulnerability_attrs)
      vulnerability_attrs.map do |id, severity, project_id, namespace_id|
        {
          noteable_type: "Vulnerability",
          noteable_id: id,
          project_id: project_id,
          namespace_id: namespace_id,
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            @new_severity,
            nil,
            comment,
            'severity',
            severity
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
  end
end
