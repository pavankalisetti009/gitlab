# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Upstream, feature_category: :virtual_registry do
  subject(:upstream) { build(:virtual_registries_packages_npm_upstream) }

  describe 'associations', :aggregate_failures do
    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::Registry')
    end
  end
end
