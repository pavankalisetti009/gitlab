# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class FormErrorsComponent < GitlabSubscriptions::Trials::FormErrorsComponent
        extend ::Gitlab::Utils::Override

        private

        override :title
        def title
          _("We're sorry, your GitLab Duo Enterprise trial could not " \
            "be created because our system did not respond successfully.")
        end
      end
    end
  end
end
