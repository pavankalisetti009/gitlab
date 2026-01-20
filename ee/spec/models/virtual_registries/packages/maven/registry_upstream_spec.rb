# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::RegistryUpstream, type: :model, feature_category: :virtual_registry do
  subject(:registry_upstream) { build(:virtual_registries_packages_maven_registry_upstream) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'belongs to a registry' do
      is_expected.to belong_to(:registry)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
        .inverse_of(:registry_upstreams)
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
        .inverse_of(:registry_upstreams)
    end
  end

  describe 'validations' do
    subject(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:upstream_id).scoped_to(:registry_id) }

    it 'validates position' do
      is_expected.to validate_numericality_of(:position)
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(20)
        .only_integer
    end

    # position is set before validation on create. Thus, we need to check the registry_id uniqueness validation
    # manually with two records that are already persisted.
    context 'for registry_id uniqueness' do
      let_it_be(:other_registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream) }

      it 'validates it' do
        other_registry_upstream.assign_attributes(registry_upstream.attributes)

        expect(other_registry_upstream.valid?).to be_falsey
        expect(other_registry_upstream.errors[:registry_id].first).to eq('has already been taken')
      end
    end
  end

  it_behaves_like 'registry upstream position sync',
    registry_factory: :virtual_registries_packages_maven_registry,
    registry_upstream_factory: :virtual_registries_packages_maven_registry_upstream

  describe '.registries_count_by_upstream_ids' do
    let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:upstream3) { create(:virtual_registries_packages_maven_upstream) }

    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:registry_upstream1) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1, upstream: upstream1)
    end

    let_it_be(:registry_upstream2) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry2, upstream: upstream1)
    end

    let_it_be(:registry_upstream3) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1, upstream: upstream2)
    end

    it 'returns count of registries grouped by upstream_id' do
      result = described_class.registries_count_by_upstream_ids([upstream1.id, upstream2.id, upstream3.id])

      expect(result).to eq(upstream1.id => 3, upstream2.id => 2, upstream3.id => 1)
    end

    it 'returns empty hash when no upstream_ids match' do
      result = described_class.registries_count_by_upstream_ids([999])

      expect(result).to eq({})
    end

    it 'returns empty hash when upstream_ids array is empty' do
      result = described_class.registries_count_by_upstream_ids([])

      expect(result).to eq({})
    end
  end
end
