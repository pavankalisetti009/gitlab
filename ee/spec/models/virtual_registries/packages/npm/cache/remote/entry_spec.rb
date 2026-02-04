# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Cache::Remote::Entry, feature_category: :virtual_registry do
  subject(:entry) { build(:virtual_registries_packages_npm_cache_remote_entry) }

  it_behaves_like 'virtual registries remote entries models',
    upstream_class: 'VirtualRegistries::Packages::Npm::Upstream',
    upstream_factory: :virtual_registries_packages_npm_upstream,
    entry_factory: :virtual_registries_packages_npm_cache_remote_entry

  describe 'object storage key' do
    it 'is set before saving' do
      expect { entry.save! }
        .to change { entry.object_storage_key }.from(nil).to(an_instance_of(String))
    end
  end
end
