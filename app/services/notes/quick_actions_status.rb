# frozen_string_literal: true

module Notes
  class QuickActionsStatus
    attr_accessor :message, :commands_only, :command_names, :error

    def initialize(message:, command_names:, commands_only:, error: false)
      @message = message
      @command_names = command_names
      @commands_only = commands_only
      @error = error
    end

    def commands_only?
      commands_only
    end

    def success?
      !error
    end

    def error?
      error
    end

    def to_h
      {
        messages: messages,
        command_names: command_names,
        commands_only: commands_only,
        error: error
      }
    end

    def messages
      return unless message.presence

      [message]
    end
  end
end
