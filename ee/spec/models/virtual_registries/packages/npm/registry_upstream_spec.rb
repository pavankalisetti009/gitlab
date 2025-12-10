# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::RegistryUpstream, feature_category: :virtual_registry do
  subject(:registry_upstream) { build(:virtual_registries_packages_npm_registry_upstream) }

  describe 'associations', :aggregate_failures do
    it { is_expected.to belong_to(:group) }

    it 'belongs to a registry' do
      is_expected.to belong_to(:registry)
        .class_name('VirtualRegistries::Packages::Npm::Registry')
        .inverse_of(:registry_upstreams)
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Npm::Upstream')
        .inverse_of(:registry_upstreams)
    end
  end
end
