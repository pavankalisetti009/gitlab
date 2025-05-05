# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistryHelper, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe '#registry_types' do
    let(:group) { build_stubbed(:group) }

    subject(:registry_types) { helper.registry_types(group, registry_types_with_counts) }

    context 'when there are available registry types' do
      let(:registry_types_with_counts) { { maven: 3 } }

      it 'returns the correct structure for registry types' do
        expect(registry_types).to be_a(Hash)
        expect(registry_types.keys).to contain_exactly(:maven)

        expect(registry_types[:maven]).to include(
          new_page_path: a_string_matching(%r{virtual_registries/maven/new}),
          landing_page_path: a_string_matching(%r{virtual_registries/maven}),
          image_path: 'illustrations/logos/maven.svg',
          count: 3,
          type_name: 'Maven'
        )
      end
    end
  end

  describe '#can_create_virtual_registry?' do
    let(:group) { build_stubbed(:group) }
    let(:user) { build_stubbed(:user) }
    let(:policy_subject) { instance_double(::VirtualRegistries::Packages::Policies::Group) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
      allow(Ability).to receive(:allowed?).with(user, :create_virtual_registry,
        policy_subject).and_return(allow_create_virtual_registry)
    end

    subject { helper.can_create_virtual_registry?(group) }

    where(:allow_create_virtual_registry, :result) do
      true  | true
      false | false
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end
end
