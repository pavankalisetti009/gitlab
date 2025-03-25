# frozen_string_literal: true

module AmazonQ
  class QuickActionsController < ApplicationController
    before_action :set_note_and_noteable
    before_action :authorize_amazon_q_action

    feature_category :duo_chat

    def create
      execute_amazon_q_command(permitted_params[:command])
    end

    private

    def set_note_and_noteable
      @note = Note.find(permitted_params[:note_id])
      @noteable = @note.noteable
    end

    def authorize_amazon_q_action
      return if Ability.allowed?(current_user, :trigger_amazon_q, @noteable)

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end

    def validate_command(command)
      ::Ai::AmazonQValidateCommandSourceService.new(
        command: command,
        source: @noteable
      ).validate
    rescue Ai::AmazonQValidateCommandSourceService::UnsupportedCommandError => error
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def execute_amazon_q_command(command)
      validate_command(command)

      Ai::AmazonQ::AmazonQTriggerService.new(
        user: current_user,
        command: command,
        source: @noteable,
        note: @note,
        input: "",
        discussion_id: @note.discussion_id
      ).execute
    end

    def permitted_params
      params.permit(:note_id, :command)
    end
  end
end
