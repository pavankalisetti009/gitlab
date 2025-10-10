# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/virtual_registries/index', feature_category: :virtual_registry do
  include VirtualRegistryHelper

  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }

  let(:registry_types_with_counts) { { maven: 3 } }

  before do
    assign(:group, group)
    assign(:registry_types_with_counts, registry_types_with_counts)
    allow(view).to receive_messages(
      current_user: user,
      can?: false,
      can_create_virtual_registry?: false,
      registry_types: registry_types(group)
    )
  end

  it 'renders the page heading' do
    render

    expect(rendered).to have_selector('h1', text: 'Virtual registry')
  end

  it 'renders registry type information' do
    render

    expect(rendered).to have_text('Maven')
    expect(rendered).to have_link('View registries',
      href: group_virtual_registries_maven_registries_and_upstreams_path(group))
  end

  context 'when user can create virtual registry' do
    before do
      allow(view).to receive(:can_create_virtual_registry?).and_return(true)
    end

    context 'when registry count is below maximum' do
      before do
        allow(view).to receive(:max_registries_count_exceeded?).with(group, :maven).and_return(false)
      end

      it 'renders create registry button' do
        render

        expect(rendered).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))
      end

      it 'does not render maximum registries message' do
        render

        expect(rendered).not_to have_text('Maximum number of registries reached.')
      end
    end

    context 'when registry count is at maximum' do
      before do
        allow(view).to receive(:max_registries_count_exceeded?).with(group, :maven).and_return(true)
      end

      it 'does not render create registry button' do
        render

        expect(rendered).not_to have_link('Create registry')
      end

      it 'renders maximum registries reached message' do
        render

        expect(rendered).to have_text('Maximum number of registries reached.')
      end
    end
  end

  context 'when user cannot create virtual registry' do
    it 'does not render create registry button' do
      render

      expect(rendered).not_to have_link('Create registry')
    end

    it 'does not render maximum registries message' do
      render

      expect(rendered).not_to have_text('Maximum number of registries reached.')
    end
  end

  context 'when there are no registries' do
    let(:registry_types_with_counts) { { maven: 0 } }

    it 'renders empty state' do
      render

      expect(rendered).to have_selector('.gl-empty-state')
    end
  end
end
