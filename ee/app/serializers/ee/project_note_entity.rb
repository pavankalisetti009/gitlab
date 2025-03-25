# frozen_string_literal: true

module EE
  module ProjectNoteEntity
    extend ActiveSupport::Concern

    prepended do
      expose :amazon_q_quick_actions_path, if: ->(note, _) { note.project.present? } do |note|
        if ::Ai::AmazonQ.connected? && note.author_id == ::Ai::Setting.instance.amazon_q_service_account_user_id
          amazon_q_quick_actions_path
        end
      end
    end
  end
end
