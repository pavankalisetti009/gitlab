# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class ResubmitComponent < Trials::ResubmitComponent
      extend ::Gitlab::Utils::Override

      private

      override :top_page_component
      def top_page_component
        GitlabSubscriptions::SelfManaged::TopPageComponent
      end
    end
  end
end
