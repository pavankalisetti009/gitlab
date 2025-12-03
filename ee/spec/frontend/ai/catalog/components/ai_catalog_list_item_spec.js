import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlTruncate, GlIcon } from '@gitlab/ui';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { AI_CATALOG_AGENTS_EDIT_ROUTE } from 'ee/ai/catalog/router/constants';
import { AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';
import {
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { mockBaseVersion, mockProjectWithGroup } from '../mock_data';

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
    project: mockProjectWithGroup,
    latestVersion: { ...mockBaseVersion, updatedAt: '2025-08-19T16:45:00Z' },
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
    disableActionItem: {
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

  const findSourceProjectTooltip = () => wrapper.findByTestId('ai-catalog-item-source-project');
  const findSourceProjectIcon = () => findSourceProjectTooltip().findComponent(GlIcon);
  const findSourceProjectText = () => findSourceProjectTooltip().findComponent(GlTruncate);
  const findVisibilityTooltip = () => wrapper.findByTestId('ai-catalog-item-visibility');
  const findExternalLabel = () => wrapper.findByTestId('ai-catalog-item-external');
  const findListItemLink = () => wrapper.findComponent(RouterLink);
  const findVisibilityIcon = () => findVisibilityTooltip().findComponent(GlIcon);
  const findDisclosureDropdown = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findFoundationalIcon = () => wrapper.findComponent(FoundationalIcon);

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
      expect(items.at(1).text()).toBe('Disable');
    });

    it('renders disable action text when passed', () => {
      createComponent({
        itemTypeConfig: {
          ...defaultItemTypeConfig,
          disableActionItem: {
            ...defaultItemTypeConfig.disableActionItem,
            text: 'Disable',
          },
        },
      });
      const items = findDisclosureDropdownItems();

      expect(items.at(1).text()).toBe('Disable');
    });

    describe('when the action items are empty but the user has permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: { ...defaultItemTypeConfig, actionItems: () => [] },
        });
      });

      it('does render the the disclosure dropdown with the disable action', () => {
        const items = findDisclosureDropdownItems();

        expect(items).toHaveLength(1);
        expect(items.at(0).text()).toBe('Disable');
      });
    });

    describe('when the action items are empty and the user does not have permission to admin the item', () => {
      beforeEach(() => {
        createComponent({
          itemTypeConfig: {
            ...defaultItemTypeConfig,
            actionItems: () => [],
            disableActionItem: {
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
        expect(findVisibilityIcon().props('name')).toBe(
          VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE_STRING],
        );
      });

      it('renders the private tooltip', () => {
        expect(findVisibilityTooltip().attributes('title')).toBe(privateTooltip);
      });
    });

    describe('when the item is public', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, public: true },
        });
      });

      it('renders the public icon with a tooltip', () => {
        expect(findVisibilityIcon().props('name')).toBe(
          VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC_STRING],
        );
      });

      it('renders the public tooltip', () => {
        expect(findVisibilityTooltip().attributes('title')).toBe(publicTooltip);
      });
    });
  });

  describe('renders list item link', () => {
    it('contains correct link href', () => {
      expect(findListItemLink().props('to')).toEqual({ name: '/items/:id', params: { id: 1 } });
    });
  });

  describe('source project attribution', () => {
    beforeEach(() => {
      createComponent({
        item: {
          ...mockItem,
          project: {
            __typename: 'Project',
            nameWithNamespace: 'Group / Project 1',
          },
        },
      });
    });
    it('renders project name text correctly', () => {
      expect(findSourceProjectText().props('text')).toBe('Group / Project 1');
    });

    it('renders tooltip correctly', () => {
      expect(findSourceProjectTooltip().attributes('title')).toBe('Group / Project 1');
    });

    describe('when project is null', () => {
      beforeEach(() => {
        createComponent({ item: { ...mockItem, project: null } });
      });

      it('renders warning icon when project is null', () => {
        expect(findSourceProjectIcon().props('name')).toBe('eye-slash');
      });

      it('renders generic project name when project is null', () => {
        expect(findSourceProjectText().props('text')).toBe('Private project');
      });

      it('renders tooltip with warning explanation when project is null', () => {
        expect(findSourceProjectTooltip().attributes('title')).toBe(
          "Managed by a private project you don't have access to.",
        );
      });
    });
  });

  describe('on disable action', () => {
    it('emits disable event', () => {
      const disableAction = findDisclosureDropdownItems().at(1);

      disableAction.vm.$emit('action');

      expect(wrapper.emitted('disable')[0]).toEqual([]);
    });
  });

  describe('foundational agent', () => {
    describe('when item is foundational', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, foundationalChat: true },
        });
      });

      it('renders foundational icon with correct props', () => {
        const foundationalIcon = findFoundationalIcon();

        expect(foundationalIcon.props('resourceId')).toBe(mockItem.id);
        expect(foundationalIcon.props('size')).toBe(16);
      });
    });

    describe('when item is not foundational', () => {
      it('does not render foundational icon', () => {
        expect(findFoundationalIcon().exists()).toBe(false);
      });
    });
  });

  describe('external agent label', () => {
    describe('when item is THIRD_PARTY_FLOW', () => {
      beforeEach(() => {
        createComponent({
          item: { ...mockItem, itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW },
        });
      });

      it('renders external label and icon', () => {
        expect(findExternalLabel().text()).toBe('External');
        expect(findExternalLabel().findComponent(GlIcon).props('name')).toBe('connected');
      });

      it('renders tooltip with correct text', () => {
        expect(findExternalLabel().attributes('title')).toBe(
          'Connects to an AI model provider outside GitLab.',
        );
      });
    });

    describe('when item is not THIRD_PARTY_FLOW', () => {
      it('does not render external indicator', () => {
        expect(findExternalLabel().exists()).toBe(false);
      });
    });
  });
});
