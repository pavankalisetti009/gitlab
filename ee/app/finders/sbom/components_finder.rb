# frozen_string_literal: true

module Sbom
  class ComponentsFinder
    DEFAULT_MAX_RESULTS = 30

    def initialize(name)
      @name = name
    end

    def execute
      components
    end

    private

    attr_reader :name

    def components
      return Sbom::Component.limit(DEFAULT_MAX_RESULTS) unless name

      Sbom::Component.by_name(name).limit(DEFAULT_MAX_RESULTS)
    end
  end
end
