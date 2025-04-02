# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestVulnerabilities
        class MarkResolvedAsDetected < AbstractTask
          include Gitlab::Utils::StrongMemoize

          def execute
            return if redetected_vulnerability_ids.blank?

            mark_as_resolved

            finding_maps
          end

          private

          def mark_as_resolved
            Gitlab::Database::SecApplicationRecord.transaction do
              create_state_transitions
              update_vulnerability_records
            end

            Note.transaction do
              results = Note.insert_all!(system_note_attrs, returning: %w[id])
              SystemNoteMetadata.insert_all!(note_metadata_attrs(results))
            end

            set_transitioned_to_detected
          end

          def redetected_vulnerability_ids
            strong_memoize(:redetected_vulnerability_ids) do
              ::Vulnerability.resolved.id_in(vulnerability_ids).pluck_primary_key
            end
          end

          def update_vulnerability_records
            ::Vulnerability.id_in(redetected_vulnerability_ids)
              .update_all(
                state: :detected,
                resolved_at: nil,
                resolved_by_id: nil
              )
          end

          def create_state_transitions
            ::Vulnerabilities::StateTransition.bulk_insert!(state_transitions)
          end

          def state_transitions
            redetected_vulnerability_ids.map do |vulnerability_id|
              ::Vulnerabilities::StateTransition.new(
                vulnerability_id: vulnerability_id,
                from_state: :resolved,
                to_state: :detected,
                created_at: now,
                updated_at: now
              )
            end
          end

          def system_note_attrs
            redetected_vulnerability_ids.map do |vulnerability_id|
              pipeline = finding_map_by_vulnerability_id(vulnerability_id).pipeline

              {
                noteable_type: "Vulnerability",
                noteable_id: vulnerability_id,
                author_id: pipeline.user_id,
                project_id: pipeline.project_id,
                namespace_id: pipeline.project.namespace_id,
                note: comment(pipeline),
                system: true,
                created_at: now,
                updated_at: now
              }
            end
          end

          def note_metadata_attrs(results)
            results.map do |row|
              id = row['id']
              {
                note_id: id,
                action: 'vulnerability_detected',
                created_at: now,
                updated_at: now
              }
            end
          end

          def set_transitioned_to_detected
            updated_finding_maps.each { |finding_map| finding_map.transitioned_to_detected = true }
          end

          def updated_finding_maps
            finding_maps.select { |finding_map| redetected_vulnerability_ids.include?(finding_map.vulnerability_id) }
          end

          def vulnerability_ids
            finding_maps.map(&:vulnerability_id)
          end

          def now
            Time.zone.now
          end
          strong_memoize_attr :now

          def comment(pipeline)
            pipeline_link = pipeline_reference(pipeline)

            format(
              s_("Vulnerabilities|changed vulnerability status to Needs Triage " \
                "because it was redetected in pipeline %{pipeline_link}"),
              { pipeline_link: pipeline_link }
            )
          end

          def pipeline_reference(pipeline)
            url = Gitlab::UrlBuilder.build(pipeline)

            "[#{pipeline.id}](#{url})"
          end

          def finding_map_by_vulnerability_id(vulnerability_id)
            finding_maps.find { |finding_map| finding_map.vulnerability_id == vulnerability_id }
          end
        end
      end
    end
  end
end
