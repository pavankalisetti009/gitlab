# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::VirtualRegistries::Packages::Maven::RegistryUpstream, feature_category: :virtual_registry do
  let(:registry_upstream) { build_stubbed(:virtual_registries_packages_maven_registry_upstream) }

  subject { described_class.new(registry_upstream).as_json }

  it { is_expected.to include(:id, :position) }
end
