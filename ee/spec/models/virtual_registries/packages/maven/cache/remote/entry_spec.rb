# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Cache::Remote::Entry, :aggregate_failures, feature_category: :virtual_registry do
  describe 'associations' do
    it { is_expected.to belong_to(:group).required }
    it { is_expected.to belong_to(:upstream).required }
  end

  it_behaves_like 'having unique enum values'

  describe 'validations' do
    context 'with a non top-level group' do
      let(:subgroup) { build(:group, parent: build(:group)) }
      let(:entry) { build(:virtual_registries_packages_maven_cache_remote_entry, group: subgroup) }

      it 'is invalid' do
        expect(entry).to be_invalid
        expect(entry.errors[:group]).to include('must be a top level Group')
      end
    end
  end

  context 'with loose foreign key on virtual_registries_container_cache_remote_entries.upstream_id' do
    it_behaves_like 'update by a loose foreign key' do
      let_it_be(:parent) { create(:virtual_registries_packages_maven_upstream) }
      let_it_be(:model) { create(:virtual_registries_packages_maven_cache_remote_entry, upstream: parent) }

      let(:find_model) { described_class.take }
    end
  end
end
