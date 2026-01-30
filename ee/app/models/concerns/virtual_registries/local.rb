# frozen_string_literal: true

module VirtualRegistries
  module Local
    extend ActiveSupport::Concern

    def local?
      true
    end

    def remote?
      false
    end
  end
end
