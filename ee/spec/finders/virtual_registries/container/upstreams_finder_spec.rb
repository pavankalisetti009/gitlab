# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::VirtualRegistries::Container::UpstreamsFinder, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstreams) { create_list(:virtual_registries_container_upstream, 2, registries: [registry]) }
  let_it_be(:other_upstream) { create(:virtual_registries_container_upstream) }

  describe '#execute' do
    let(:params) { {} }

    subject(:find_upstreams) { described_class.new(group, params).execute }

    it { is_expected.to match_array(upstreams).and be_a(ActiveRecord::Relation) }

    context 'with upstream_name' do
      let(:params) { { upstream_name: 'foo' } }

      let_it_be(:upstream1) do
        create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream-foo')
      end

      let_it_be(:upstream2) do
        create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream-bar')
      end

      it 'returns upstreams which match the given upstream_name' do
        expect(find_upstreams).to match_array([upstream1])
      end
    end
  end
end
