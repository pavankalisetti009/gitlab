import { GlDisclosureDropdownItem, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import {
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import ListItem from '~/vue_shared/components/resource_lists/list_item.vue';

describe('AiCatalogListItem', () => {
  let wrapper;

  const mockId = 1;

  const mockItem = {
    id: `gid://gitlab/Ai::Catalog::Item/${mockId}`,
    name: 'Test AI Agent',
    itemType: 'AGENT',
    description: 'A helpful AI assistant for testing purposes',
    public: false,
  };

  const mockUrl = '/agent/1';

  const mockRouter = {
    resolve: jest.fn().mockReturnValue({ href: `/agent/${mockId}` }),
    push: jest.fn(),
  };

  const publicTooltip = 'Public Item';
  const privateTooltip = 'Private Item';

  const createComponent = (item = mockItem) => {
    wrapper = shallowMountExtended(AiCatalogListItem, {
      propsData: {
        item,
        itemTypeConfig: {
          actionItems: (itemId) => [
            {
              text: 'Test Run',
              to: {
                name: AI_CATALOG_AGENTS_RUN_ROUTE,
                params: { id: itemId },
              },
              icon: 'rocket-launch',
            },
            {
              text: 'Edit',
              to: {
                name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                params: { id: itemId },
              },
              icon: 'pencil',
            },
          ],
          visibilityTooltip: {
            public: publicTooltip,
            private: privateTooltip,
          },
        },
      },
      mocks: {
        $route: {
          path: '/agents/:id',
        },
        $router: mockRouter,
      },
    });
  };

  const findListItem = () => wrapper.findComponent(ListItem);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the list item container with correct properties', () => {
      const listItem = findListItem();
      const expectedResource = {
        ...mockItem,
        id: mockId,
        avatarLabel: mockItem.name,
        avatarUrl: null,
        descriptionHtml: mockItem.description,
        fullName: mockItem.name,
        relativeWebUrl: mockUrl,
      };

      expect(listItem.exists()).toBe(true);
      expect(listItem.props('resource')).toEqual(expectedResource);
    });

    it('renders the actions passed in a prop in a disclosure dropdown', () => {
      const items = findDisclosureDropdownItems();

      expect(items).toHaveLength(3);
      expect(items.at(0).text()).toBe('Test Run');
      expect(items.at(1).text()).toBe('Edit');
      expect(items.at(2).text()).toBe('Delete');
      expect(items.at(2).attributes('variant')).toBe('danger');
    });

    describe('when the item is private', () => {
      it('renders the private icon with a tooltip', () => {
        const icon = findIcon();

        expect(icon.props('name')).toBe(VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE_STRING]);
        expect(icon.attributes('title')).toBe(privateTooltip);
      });
    });

    describe('when the item is public', () => {
      beforeEach(() => {
        createComponent({ ...mockItem, public: true });
      });

      it('renders the public icon with a tooltip', () => {
        const icon = findIcon();

        expect(icon.props('name')).toBe(VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC_STRING]);
        expect(icon.attributes('title')).toBe(publicTooltip);
      });
    });
  });

  describe('on list item click', () => {
    const mockEvent = {
      preventDefault: jest.fn(),
    };

    it('emits click event', () => {
      const listItem = findListItem();

      listItem.vm.$emit('click-avatar', mockEvent);

      expect(mockRouter.push).toHaveBeenCalledWith({
        query: { [AI_CATALOG_SHOW_QUERY_PARAM]: mockId },
      });
    });
  });

  describe('on delete action', () => {
    it('emits delete event', () => {
      const deleteAction = findDisclosureDropdownItems().at(2);

      deleteAction.vm.$emit('action');

      expect(wrapper.emitted('delete')[0]).toEqual([]);
    });
  });
});
