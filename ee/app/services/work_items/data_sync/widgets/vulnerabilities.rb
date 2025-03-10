# frozen_string_literal: true

module WorkItems
  module DataSync
    module Widgets
      class Vulnerabilities < Base
        def after_save_commit
          # copy Vulnerabilities
        end

        def post_move_cleanup
          # do it
        end
      end
    end
  end
end
