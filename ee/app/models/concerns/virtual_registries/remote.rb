# frozen_string_literal: true

module VirtualRegistries
  module Remote
    extend ActiveSupport::Concern

    def local?
      false
    end

    def remote?
      true
    end
  end
end
