# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Registry, type: :model, feature_category: :virtual_registry do
  subject(:registry) { build(:virtual_registries_packages_maven_registry) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'has many registry upstream' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::RegistryUpstream')
        .inverse_of(:registry)
    end

    it 'has many upstreams' do
      is_expected.to have_many(:upstreams)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:group) }
    it { is_expected.to validate_presence_of(:group) }
  end

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
    let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry) }

    subject { described_class.for_group(group) }

    it { is_expected.to eq([registry]) }
  end

  describe 'upstreams ordering' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:upstream1) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registry: registry)
    end

    let_it_be(:upstream2) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registry: registry)
    end

    let_it_be(:upstream3) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registry: registry)
    end

    subject { registry.reload.upstreams.to_a }

    it { is_expected.to eq([upstream1, upstream2, upstream3]) }
  end

  describe 'registry destruction' do
    let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

    let(:registry) { upstream.registry }

    subject(:destroy_registry) { registry.destroy! }

    it 'deletes the upstream and the registry_upstream' do
      expect { destroy_registry }.to change { described_class.count }.by(-1)
       .and change { VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
       .and change { VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
    end
  end
end
