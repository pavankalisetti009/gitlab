import { GlButton, GlDrawer, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemDrawer from 'ee/ai/catalog/components/ai_catalog_item_drawer.vue';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import { AI_CATALOG_AGENTS_EDIT_ROUTE } from 'ee/ai/catalog/router/constants';

import { mockAgent, mockFlow } from '../mock_data';

describe('CatalogItemDrawer', () => {
  let wrapper;

  const defaultProps = {
    isOpen: false,
    editRoute: AI_CATALOG_AGENTS_EDIT_ROUTE,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemDrawer, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findDrawerContent = () => wrapper.findByTestId('ai-catalog-item-drawer-content');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEditButton = () => wrapper.findComponent(GlButton);

  it('renders drawer as closed', () => {
    createComponent();
    expect(findDrawer().props('open')).toBe(false);
  });

  describe('with activeItem', () => {
    beforeEach(() => {
      createComponent({
        props: {
          isOpen: true,
          activeItem: mockAgent,
        },
      });
    });

    it('renders drawer as open', () => {
      expect(findDrawer().props('open')).toBe(true);
    });

    it('displays the item name', () => {
      expect(wrapper.text()).toContain(mockAgent.name);
    });

    it('links to edit page', () => {
      const button = findEditButton();
      expect(button.exists()).toBe(true);

      expect(button.props('to')).toEqual({
        name: AI_CATALOG_AGENTS_EDIT_ROUTE,
        params: { id: 1 },
      });
    });

    describe('when the user does not have permission to admin the item', () => {
      it('does not link to edit page', () => {
        createComponent({
          props: {
            isOpen: true,
            activeItem: {
              ...mockAgent,
              userPermissions: { adminAiCatalogItem: false },
            },
          },
        });

        expect(findEditButton().exists()).toBe(false);
      });
    });
  });

  describe('drawer content', () => {
    beforeEach(() => {
      createComponent({
        props: {
          isOpen: true,
          activeItem: mockFlow,
        },
      });
    });

    it('renders description', () => {
      expect(findDrawerContent().html()).toContain(mockFlow.description);
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders loading icon when isItemDetailsLoading is true', async () => {
      await createComponent({
        props: {
          isOpen: true,
          isItemDetailsLoading: true,
          activeItem: mockFlow,
        },
      });

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it.each`
      activeItem   | component
      ${mockAgent} | ${AiCatalogAgentDetails}
      ${mockFlow}  | ${AiCatalogFlowDetails}
    `(
      'renders correct component when activeItem is $activeItem.itemType',
      ({ activeItem, component }) => {
        createComponent({
          props: {
            isOpen: true,
            activeItem,
          },
        });

        expect(wrapper.findComponent(component).props('item')).toEqual(activeItem);
      },
    );
  });

  describe('without editRoute', () => {
    it('does not link to edit page', () => {
      createComponent({
        props: { isOpen: true, editRoute: null },
      });

      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('closing the drawer', () => {
    it('emits `close` event when drawer is closed', () => {
      createComponent({
        props: { isOpen: true },
      });

      findDrawer().vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
