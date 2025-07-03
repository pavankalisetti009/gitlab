import { GlButton, GlBadge, GlMarkdown, GlLink, GlAvatar } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';

describe('AiCatalogListItem', () => {
  let wrapper;

  const mockItem = {
    id: 'gid://gitlab/Ai::Catalog::Item/1',
    name: 'Test AI Agent',
    itemType: 'AGENT',
    description: 'A helpful AI assistant for testing purposes',
  };

  const createComponent = (item = mockItem) => {
    wrapper = shallowMountExtended(AiCatalogListItem, {
      propsData: {
        item,
      },
      mocks: {
        $options: {
          routes: {
            show: '/agents/:id',
            run: '/agents/:id/run',
          },
        },
      },
    });
  };

  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findLink = () => wrapper.findComponent(GlLink);
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findTypeBadge = () => findBadges().at(0);
  const findMarkdown = () => wrapper.findComponent(GlMarkdown);
  const findRunButton = () => wrapper.findComponent(GlButton);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the list item container with correct attributes', () => {
      const listItem = wrapper.findByTestId('ai-catalog-list-item');

      expect(listItem.exists()).toBe(true);
      expect(listItem.element.tagName).toBe('LI');
    });

    it('renders avatar with correct props', () => {
      const avatar = findAvatar();

      expect(avatar.exists()).toBe(true);
      expect(avatar.props('alt')).toBe('Test AI Agent avatar');
      expect(avatar.props('entityName')).toBe('Test AI Agent');
      expect(avatar.props('size')).toBe(48);
    });

    it('displays the agent name as a link', () => {
      const link = findLink();

      expect(link.exists()).toBe(true);
      expect(link.text()).toBe('Test AI Agent');
      expect(link.props('to')).toEqual({
        name: '/agents/:id',
        params: { id: 1 },
      });
    });

    it('displays type badge with correct variant and text', () => {
      const typeBadge = findTypeBadge();

      expect(typeBadge.exists()).toBe(true);
      expect(typeBadge.props('variant')).toBe('neutral');
      expect(typeBadge.text()).toBe('agent');
    });

    it('displays run button with correct props', () => {
      const runButton = findRunButton();

      expect(runButton.exists()).toBe(true);
      expect(runButton.text()).toBe('Run');
      expect(runButton.props('to')).toEqual({
        name: '/agents/:id/run',
        params: { id: 1 },
      });
    });

    it('displays description', () => {
      const markdown = findMarkdown();

      expect(markdown.exists()).toBe(true);
      expect(markdown.text()).toBe('A helpful AI assistant for testing purposes');
      expect(markdown.props('compact')).toBe(true);
    });
  });
});
