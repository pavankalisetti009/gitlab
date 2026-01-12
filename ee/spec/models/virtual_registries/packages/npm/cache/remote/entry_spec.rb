# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Cache::Remote::Entry, feature_category: :virtual_registry do
  subject(:entry) { build(:virtual_registries_packages_npm_cache_remote_entry) }

  it { is_expected.to include_module(ShaAttribute) }

  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).required
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Npm::Upstream')
        .required
        .inverse_of(:cache_remote_entries)
    end
  end

  it_behaves_like 'having unique enum values'

  describe 'object storage key' do
    it 'is set before saving' do
      expect { entry.save! }
        .to change { entry.object_storage_key }.from(nil).to(an_instance_of(String))
    end
  end

  context 'with loose foreign key on virtual_registries_npm_cache_remote_entries.upstream_id' do
    it_behaves_like 'update by a loose foreign key' do
      let_it_be(:parent) { create(:virtual_registries_packages_npm_upstream) }
      let_it_be(:model) { create(:virtual_registries_packages_npm_cache_remote_entry, upstream: parent) }

      let(:find_model) { described_class.take }
    end
  end
end
