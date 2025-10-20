# frozen_string_literal: true

module Geo
  class PackagesNugetSymbolRegistry < Geo::BaseRegistry
    include ::Geo::ReplicableRegistry
    include ::Geo::VerifiableRegistry

    MODEL_CLASS = ::Packages::Nuget::Symbol
    MODEL_FOREIGN_KEY = :packages_nuget_symbol_id

    belongs_to :packages_nuget_symbol, class_name: 'Packages::Nuget::Symbol'
  end
end
