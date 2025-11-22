import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RecentlyViewedWidget from '~/homepage/components/recently_viewed_widget.vue';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import RecentlyViewedItemsQuery from 'ee_else_ce/homepage/graphql/queries/recently_viewed_items.query.graphql';

Vue.use(VueApollo);

describe('RecentlyViewedWidget EE', () => {
  let wrapper;

  const mockRecentlyViewedResponse = {
    data: {
      currentUser: {
        id: 123,
        recentlyViewedItems: [
          {
            viewedAt: '2025-06-19T15:30:00Z',
            itemType: 'Issue',
            item: {
              __typename: 'Epic',
              id: 'epic-1',
              title: 'Q3 Development Roadmap',
              webUrl: '/groups/company/-/epics/999',
            },
          },
        ],
      },
    },
  };

  const recentlyViewedQuerySuccessHandler = jest.fn().mockResolvedValue(mockRecentlyViewedResponse);

  const createComponent = ({ queryHandler = recentlyViewedQuerySuccessHandler } = {}) => {
    const mockApollo = createMockApollo([[RecentlyViewedItemsQuery, queryHandler]]);

    wrapper = shallowMountExtended(RecentlyViewedWidget, {
      apolloProvider: mockApollo,
    });
  };

  const findItemLinks = () => wrapper.findAll('a[href^="/"]');
  const findItemIcons = () => wrapper.findAllComponents(GlIcon);
  const findItemsList = () => wrapper.find('ul');
  const findListItems = () => findItemsList().findAll('li');
  const findItemsByIconName = (iconName) =>
    findListItems().wrappers.filter((w) => w.findComponent(GlIcon).props('name') === iconName);
  const findTooltipComponents = () => wrapper.findAllComponents(TooltipOnTruncate);

  describe('GraphQL query', () => {
    it('makes the correct GraphQL query', () => {
      createComponent();

      expect(recentlyViewedQuerySuccessHandler).toHaveBeenCalled();
    });

    it('updates component data when query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findItemLinks()).toHaveLength(1);
    });
  });

  describe('items rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the correct number of items', () => {
      expect(findItemLinks()).toHaveLength(1);
    });

    it('adds correct icon to epics', () => {
      const epicItems = findItemsByIconName('work-item-epic');

      expect(epicItems).toHaveLength(1);
      expect(epicItems.at(0).text()).toBe('Q3 Development Roadmap');
    });

    it('renders items with correct URLs', () => {
      const links = findItemLinks();

      expect(links.at(0).attributes('href')).toBe('/groups/company/-/epics/999');
    });

    it('renders items with correct icons', () => {
      const icons = findItemIcons();

      expect(icons.at(0).props('name')).toBe('work-item-epic');
    });

    it('renders tooltip components for each item', () => {
      const tooltips = findTooltipComponents();

      expect(tooltips).toHaveLength(1);
      expect(tooltips.at(0).props('title')).toBe('Q3 Development Roadmap');
    });
  });
});
