# frozen_string_literal: true

module Admin
  module Ai
    module SelfHostedModelsHelper
      def model_choices_as_options
        ::Ai::SelfHostedModel
          .models
          .map { |name, _| { modelValue: name.upcase, modelName: name.capitalize.tr("_", " ") } }
      end
    end
  end
end
