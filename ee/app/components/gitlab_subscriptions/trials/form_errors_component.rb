# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class FormErrorsComponent < ViewComponent::Base
      include SafeFormatHelper

      # @param [errors] possible errors from backend

      def initialize(errors:)
        @errors = errors
      end

      def call
        render Pajamas::AlertComponent.new(
          variant: :danger,
          dismissible: false,
          title: title,
          alert_options: { class: 'gl-mt-3 gl-mb-5' }
        ).with_body_content(content)
      end

      private

      attr_reader :errors

      def title
        _("We're sorry, your trial could not be created because our system did not respond successfully.")
      end

      def content
        safe_format(
          errors_message,
          tag_pair(support_link, :support_link_start, :support_link_end)
        )
      end

      def support_link
        link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
      end

      def errors_message
        support_message = _(
          'Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance'
        )
        full_message = [support_message, errors.to_sentence.presence].compact.join(': ')

        "#{full_message}."
      end
    end
  end
end
