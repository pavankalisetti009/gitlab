# frozen_string_literal: true

module EE
  # Upload EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Upload` model
  module Upload
    extend ActiveSupport::Concern

    prepended do
      include ::Gitlab::SQL::Pattern
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :upload_state)

      with_replicator ::Geo::UploadReplicator

      scope :for_model, ->(model) { where(model_id: model.id, model_type: model.class.name) }
      scope :with_verification_state, ->(state) { joins(:upload_state).where(upload_states: { verification_state: verification_state_value(state) }) }
      scope :by_checksum, ->(value) { where(checksum: value) }

      has_one :upload_state,
        autosave: false,
        inverse_of: :upload,
        class_name: '::Geo::UploadState'

      around_save :ignore_save_verification_details_in_transaction, prepend: true

      def ignore_save_verification_details_in_transaction(&blk)
        ::Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
          %w[upload_states], url: "https://gitlab.com/gitlab-org/gitlab/-/issues/398199", &blk)
      end

      def verification_state_object
        upload_state
      end

      def upload_state
        super || build_upload_state
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of uploads based on the query given in `query`.
      #
      # @param [String] query term that will search over upload :checksum attribute
      #
      # @return [ActiveRecord::Relation<Upload>] a collection of uploads
      def search(query)
        return all if query.empty?

        by_checksum(query)
      end

      # @return [ActiveRecord::Relation<Upload>] scope observing selective sync
      #          settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        replicables    = params.fetch(:replicables, all)
        primary_key_in = params[:primary_key_in].presence
        replicables    = replicables.primary_key_in(primary_key_in) if primary_key_in

        return replicables unless node.selective_sync?

        if node.selective_sync_by_namespaces? || node.selective_sync_by_shards?
          uploads_for_selected_namespaces(node, replicables)
        elsif node.selective_sync_by_organizations?
          uploads_for_selected_organizations(node, replicables)
        else
          raise ::Geo::Errors::UnknownSelectiveSyncType.new(selective_sync_type: node.selective_sync_type)
        end
      end

      def uploads_for_selected_namespaces(node, replicables)
        namespace_ids = node.namespaces_for_group_owned_replicables.select(:id)
        project_ids = ::Project.selective_sync_scope(node).select(:id)

        group_attachments(replicables, namespace_ids)
          .or(project_attachments(replicables, project_ids))
          .or(other_attachments(replicables))
      end

      def uploads_for_selected_organizations(node, replicables)
        organization_ids = node.organizations.pluck_primary_key
        return none if organization_ids.empty?

        user_ids = ::Organizations::OrganizationUser.in_organization(organization_ids).select(:user_id)
        namespace_ids = node.namespaces_for_group_owned_replicables.select(:id)
        project_ids = ::Project.selective_sync_scope(node).select(:id)

        replicables
            .where(organization_id: organization_ids)
            .or(replicables.where(namespace_id: namespace_ids))
            .or(replicables.where(project_id: project_ids))
            .or(replicables.where(uploaded_by_user_id: user_ids))
      end

      # @return [ActiveRecord::Relation<Upload>] scope of Namespace-associated uploads observing selective sync settings of the given node
      def group_attachments(replicables, namespace_ids)
        replicables.where(model_type: 'Namespace', model_id: namespace_ids)
      end

      # @return [ActiveRecord::Relation<Upload>] scope of Project-associated uploads observing selective sync settings of the given node
      def project_attachments(replicables, project_ids)
        replicables.where(model_type: 'Project', model_id: project_ids)
      end

      # @return [ActiveRecord::Relation<Upload>] scope of uploads which are not associated with Namespace or Project
      def other_attachments(replicables)
        replicables.where.not(model_type: %w[Namespace Project])
      end

      override :verification_state_table_class
      def verification_state_table_class
        ::Geo::UploadState
      end
    end
  end
end
