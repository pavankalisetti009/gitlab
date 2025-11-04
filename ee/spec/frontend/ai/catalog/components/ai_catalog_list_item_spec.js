import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon } from '@gitlab/ui';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import { AI_CATALOG_AGENTS_EDIT_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';

import { mockBaseLatestVersion } from '../mock_data';

describe('AiCatalogListItem', () => {
  let wrapper;

  const mockId = 1;

  const mockItem = {
    id: `gid://gitlab/Ai::Catalog::Item/${mockId}`,
    createdAt: '2025-08-19T16:45:00Z',
    name: 'Test AI Agent',
    itemType: 'AGENT',
    description: 'A helpful AI assistant for testing purposes',
    public: false,
    updatedAt: '2025-08-19T16:45:00Z',
    latestVersion: { ...mockBaseLatestVersion, updatedAt: '2025-08-19T16:45:00Z' },
    userPermissions: {
      readAiCatalogItem: true,
      adminAiCatalogItem: true,
    },
  };

  const mockRouter = {
    resolve: jest.fn().mockReturnValue({ href: `/agent/${mockId}` }),
    push: jest.fn(),
  };

  const publicTooltip = 'Public Item';
  const privateTooltip = 'Private Item';

  const defaultItemTypeConfig = {
    actionItems: (itemId) => [
      {
        text: 'Edit',
        to: {
          name: AI_CATALOG_AGENTS_EDIT_ROUTE,
          params: { id: itemId },
        },
        icon: 'pencil',
      },
    ],
    deleteActionItem: {
      showActionItem: () => true,
    },
    showRoute: '/items/:id',
    visibilityTooltip: {
      public: publicTooltip,
      private: privateTooltip,
    },
  };

  const createComponent = ({ item = mockItem, itemTypeConfig = defaultItemTypeConfig } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListItem, {
      propsData: {
        item,
        itemTypeConfig,
      },
      mocks: {
        $route: {
          path: '/agents/:id',
        },
        $router: mockRouter,
      },
      stubs: {
        RouterLink,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findTooltip = () => wrapper.findByTestId('ai-catalog-item-tooltip');
  const findListItemLink = () => wrapper.findComponent(RouterLink);
  const findDisclosureDropdown = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the list item with the correct link URL', () => {
      const listItemLink = findListItemLink();

      expect(listItemLink.exists()).toBe(true);
      expect(listItemLink.props('to')).toEqual({ name: '/items/:id', params: { id: 1 } });
    });

    it('renders the actions passed in a prop in a disclosure dropdown', () => {
      const items = findDisclosureDropdownItems();

      expect(findDisclosureDropdown().exists()).toBe(true);
      expect(items).toHaveLength(2);
      expect(items.at(0).text()).toBe('Edit');
      expect(items.at(1).text()).toBe('Delete');
      expect(items.at(1).attributes('variant')).toBe('danger');
    });

    it('renders delete action text when passed', () => {
      createComponent({
        itemTypeConfig: {
          ...defaultItemTypeConfig,
          deleteActionItem: {
            ...defaultItemTypeConfig.deleteActionItem,
            text: 'Remove',
          },
        },
      });
      const items = findDisclosureDropdownItems();

      expect(items.at(1).text()).toBe('Remove');
    });

    describe('when the action items are empty but the user has permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: { ...defaultItemTypeConfig, actionItems: () => [] },
        });
      });

      it('does render the the disclosure dropdown with the delete action', () => {
        const items = findDisclosureDropdownItems();

        expect(items).toHaveLength(1);
        expect(items.at(0).text()).toBe('Delete');
      });
    });

    describe('when the action items are empty and the user does not have permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: {
            ...defaultItemTypeConfig,
            actionItems: () => [],
            deleteActionItem: {
              showActionItem: () => false,
            },
          },
        });
      });

      it('does not render the the disclosure dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('when the item is private', () => {
      it('renders the private icon with a tooltip', () => {
        const icon = findIcon();

        expect(icon.props('name')).toBe(VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE_STRING]);
      });

      it('renders the private tooltip', () => {
        const tooltip = findTooltip();

        expect(tooltip.attributes('title')).toBe(privateTooltip);
      });
    });

    describe('when the item is public', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, public: true },
        });
      });

      it('renders the public icon with a tooltip', () => {
        const icon = findIcon();

        expect(icon.props('name')).toBe(VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC_STRING]);
      });

      it('renders the public tooltip', () => {
        const tooltip = findTooltip();

        expect(tooltip.attributes('title')).toBe(publicTooltip);
      });
    });
  });

  describe('renders list item link', () => {
    it('contains correct link href', () => {
      expect(findListItemLink().props('to')).toEqual({ name: '/items/:id', params: { id: 1 } });
    });
  });

  describe('on delete action', () => {
    it('emits delete event', () => {
      const deleteAction = findDisclosureDropdownItems().at(1);

      deleteAction.vm.$emit('action');

      expect(wrapper.emitted('delete')[0]).toEqual([]);
    });
  });
});
