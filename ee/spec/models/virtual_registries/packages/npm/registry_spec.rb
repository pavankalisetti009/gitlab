# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Registry, feature_category: :virtual_registry do
  subject(:registry) { build(:virtual_registries_packages_npm_registry) }

  describe 'associations', :aggregate_failures do
    it { is_expected.to belong_to(:group) }

    it 'has many registry upstream' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::RegistryUpstream')
        .inverse_of(:registry)
    end

    it 'has many upstreams' do
      is_expected.to have_many(:upstreams)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::Upstream')
    end
  end

  it_behaves_like 'virtual registries: upstreams ordering',
    registry_factory: :virtual_registries_packages_npm_registry,
    upstream_factory: :virtual_registries_packages_npm_upstream
end
