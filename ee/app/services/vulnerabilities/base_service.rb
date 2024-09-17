# frozen_string_literal: true

module Vulnerabilities
  class BaseService
    include Gitlab::Allowable

    def initialize(user, vulnerability)
      @user = user
      @vulnerability = vulnerability
      @project = vulnerability.project
    end

    private

    def update_vulnerability_with(params)
      Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
        %w[
          notes
          system_note_metadata
          vulnerability_user_mentions
          vulnerability_state_transitions
          vulnerability_feedback
          vulnerabilities
        ], url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/482672'
      ) do
        @vulnerability.transaction do
          yield if block_given?

          update_with_note(params)
        end

        update_statistics
      end
    end

    def update_with_note(params)
      return false unless @vulnerability.update(params)

      # The following service call alters the `previous_changes` of the vulnerability object
      # therefore, we are sending the cloned object as that information is important for the rest of the logic.
      SystemNoteService.change_vulnerability_state(@vulnerability.clone, @user)
      true
    end

    def update_statistics
      Vulnerabilities::Statistics::UpdateService.update_for(@vulnerability) if @vulnerability.previous_changes.present?
    end

    def authorized?
      can?(@user, :admin_vulnerability, @project)
    end
  end
end
