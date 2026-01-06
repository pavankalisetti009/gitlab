# frozen_string_literal: true

module Ai
  module DuoCodeReview
    module Modes
      class Disabled < Base
        def mode
          :disabled
        end

        def enabled?
          false
        end

        def active?
          true
        end
      end
    end
  end
end
