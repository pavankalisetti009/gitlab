import { GlButton, GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import { mockAgent } from '../mock_data';

describe('CatalogItemDrawer', () => {
  let wrapper;

  const createComponent = ({ isOpen = false, activeItem = mockAgent } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemDrawer, {
      propsData: {
        isOpen,
        activeItem,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findEditButton = () => wrapper.findComponent(GlButton);

  it('renders drawer with correct props', () => {
    createComponent();
    expect(findDrawer().props('open')).toBe(false);
  });

  describe('with activeItem', () => {
    beforeEach(() => {
      createComponent({ isOpen: true });
    });

    it('renders drawer with correct props', () => {
      expect(findDrawer().props('open')).toBe(true);
    });

    it('displays the item name', () => {
      expect(wrapper.text()).toContain(mockAgent.name);
    });

    it('links to edit page', () => {
      createComponent({ isOpen: true });
      const button = findEditButton();
      expect(button.exists()).toBe(true);

      expect(button.props('to')).toEqual({
        name: AI_CATALOG_AGENTS_SHOW_ROUTE,
        params: { id: 1 },
      });
    });
  });

  describe('closing the drawer', () => {
    it('emits `close` event when drawer is closed', () => {
      createComponent({ isOpen: true });

      findDrawer().vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
