# frozen_string_literal: true

module EE
  module ReadmeHelper
    extend ActiveSupport::Concern

    prepended do
      include RemoteDevelopment::ReadmeHelper
    end
  end
end
