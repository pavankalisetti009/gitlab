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

    it 'has many local_upstreams' do
      is_expected.to have_many(:local_upstreams)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Local::Upstream')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:group_id) }
  end

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
    let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry) }

    subject { described_class.for_group(group) }

    it { is_expected.to eq([registry]) }
  end

  it_behaves_like 'virtual registries: upstreams ordering',
    registry_factory: :virtual_registries_packages_maven_registry,
    upstream_factory: :virtual_registries_packages_maven_upstream

  it_behaves_like 'virtual registries: group registry limit',
    registry_factory: :virtual_registries_packages_maven_registry

  it_behaves_like 'virtual registries: has exclusive upstreams',
    registry_factory: :virtual_registries_packages_maven_registry,
    upstream_factory: :virtual_registries_packages_maven_upstream

  it_behaves_like 'virtual registries: registry destruction',
    registry_factory: :virtual_registries_packages_maven_registry,
    upstream_factory: :virtual_registries_packages_maven_upstream,
    registry_upstream_factory: :virtual_registries_packages_maven_registry_upstream,
    upstream_class: VirtualRegistries::Packages::Maven::Upstream,
    registry_upstream_class: VirtualRegistries::Packages::Maven::RegistryUpstream

  describe '#purge_cache!' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry1, registry2]) }
    let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry1]) }

    it 'bulk enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Cache::MarkEntriesForDestructionWorker)
        .to receive(:bulk_perform_async_with_contexts)
        .with([upstream2], arguments_proc: kind_of(Proc), context_proc: kind_of(Proc))

      registry1.purge_cache!
    end
  end
end
