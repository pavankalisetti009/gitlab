# frozen_string_literal: true

module Ai
  module Avatars
    class LoadService
      def initialize(item)
        @item = item
      end

      def execute
        return unless avatar_filename

        Rails.root.join('lib', 'assets', 'images', 'bot_avatars', avatar_filename).open
      rescue Errno::ENOENT => e
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
        nil
      end

      private

      def avatar_filename
        if @item.third_party_flow?
          'external-agent.png'
        elsif @item.flow? && @item.foundational_flow_reference.present?
          get_foundational_flow_avatar
        elsif @item.flow?
          "custom-flow-#{rand(1..8)}.png"
        end
      end

      def get_foundational_flow_avatar
        workflow_definition = ::Ai::Catalog::FoundationalFlow[@item.foundational_flow_reference]

        workflow_definition&.avatar
      end
    end
  end
end
