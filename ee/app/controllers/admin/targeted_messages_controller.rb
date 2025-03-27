# frozen_string_literal: true

module Admin
  class TargetedMessagesController < Admin::ApplicationController
    feature_category :acquisition

    before_action :verify_targeted_messages_enabled!
    before_action :find_targeted_message, only: [:edit, :update]

    def index
      @targeted_messages = Notifications::TargetedMessage.all
    end

    def new
      @targeted_message = Notifications::TargetedMessage.new
    end

    def create
      @targeted_message = Notifications::TargetedMessage.new(targeted_message_params)
      success = @targeted_message.save

      if success
        redirect_to admin_targeted_messages_path,
          notice: s_('TargetedMessages|Targeted message was successfully created.')
      else
        flash[:alert] = format(s_("TargetedMessages|Failed to create targeted message: " \
          "%{error_message}"), error_message: @targeted_message.errors.full_messages.to_sentence)
        render :new
      end
    end

    def edit; end

    def update
      success = @targeted_message.update(targeted_message_params)

      if success
        redirect_to admin_targeted_messages_path,
          notice: s_('TargetedMessages|Targeted message was successfully updated.')
      else
        flash[:alert] = format(s_("TargetedMessages|Failed to update targeted message: " \
          "%{error_message}"), error_message: @targeted_message.errors.full_messages.to_sentence)
        render :edit
      end
    end

    private

    def find_targeted_message
      @targeted_message = Notifications::TargetedMessage.find(params.permit(:id)[:id])
    end

    def verify_targeted_messages_enabled!
      render_404 unless Feature.enabled?(:targeted_messages_admin_ui, :instance) &&
        ::Gitlab::Saas.feature_available?(:targeted_messages)
    end

    def targeted_message_params
      base_params = params.require(:targeted_message).permit(:target_type, :namespace_ids_csv)

      return base_params unless base_params[:namespace_ids_csv].present?

      base_params.merge(namespace_ids: valid_namespace_ids_from_csv(base_params.delete(:namespace_ids_csv)))
    end

    def valid_namespace_ids_from_csv(csv)
      result = Notifications::TargetedMessages::ProcessCsvService.new(csv).execute

      if result.success?
        invalid_namespace_ids, valid_namespace_ids = result.payload.values_at(:invalid_namespace_ids,
          :valid_namespace_ids)

        if invalid_namespace_ids.any?
          invalid_ids_msg = if invalid_namespace_ids.size <= 5
                              invalid_namespace_ids.join(", ")
                            else
                              "#{invalid_namespace_ids.first(5).join(', ')} and #{invalid_namespace_ids.size - 5} more"
                            end

          flash[:warning] = format(s_("TargetedMessages|The following namespace ids were invalid and have been " \
            "ignored: %{invalid_ids_message}"), invalid_ids_message: invalid_ids_msg)
        end

        valid_namespace_ids
      else
        flash[:warning] =
          format(s_("TargetedMessages|Failed to assign namespaces due to error processing CSV: %{error_message}"),
            error_message: result.message)
        []
      end
    end
  end
end
