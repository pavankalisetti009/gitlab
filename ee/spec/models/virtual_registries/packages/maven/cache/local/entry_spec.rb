# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Cache::Local::Entry, feature_category: :virtual_registry do
  subject(:cache_entry) { build(:virtual_registries_packages_maven_cache_local_entry) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:relative_path) }
    it { is_expected.to validate_length_of(:relative_path).is_at_most(1024) }
    it { is_expected.to allow_value('foo/bar').for(:relative_path) }
    it { is_expected.not_to allow_value('foo/ bar').for(:relative_path) }
  end

  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).class_name('Group')
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
        .required
        .inverse_of(:cache_local_entries)
    end

    it 'belongs to a package file' do
      is_expected.to belong_to(:package_file)
        .class_name('Packages::PackageFile')
        .required
    end
  end
end
