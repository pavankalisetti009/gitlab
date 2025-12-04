import { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import { mockAgents, mockPageInfo, mockItemTypeConfig } from '../mock_data';

describe('AiCatalogListWrapper', () => {
  let wrapper;

  const mockItems = mockAgents;
  const mockEmptyStateTitle = 'Get started with AI';
  const mockEmptyStateDescription = 'Build agents and flows';
  const mockEmptyStateButtonHref = '/explore/ai-catalog';
  const mockEmptyStateButtonText = 'Explore AI Catalog';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListWrapper, {
      propsData: {
        items: mockItems,
        itemTypeConfig: mockItemTypeConfig,
        isLoading: false,
        pageInfo: mockPageInfo,
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
        ...props,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlFilteredSearch component', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('renders AiCatalogList component', () => {
      expect(findAiCatalogList().exists()).toBe(true);
    });

    it('passes correct props to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        items: mockItems,
        isLoading: false,
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
      });
    });

    it('initializes with empty search term', () => {
      expect(findAiCatalogList().props('search')).toBe('');
    });
  });

  describe('search functionality', () => {
    const searchTerm = 'test search';
    const setSearch = () => findFilteredSearch().vm.$emit('submit', [searchTerm]);

    beforeEach(() => {
      createComponent();
    });

    it('updates search term and emits search event with filters when search is submitted', async () => {
      setSearch();

      await nextTick();

      expect(findAiCatalogList().props('search')).toBe(searchTerm);
      expect(wrapper.emitted('search')).toHaveLength(1);
      expect(wrapper.emitted('search')[0]).toEqual([[searchTerm]]);
    });

    it('clears search term when clear is triggered', async () => {
      // Set a search term first
      setSearch();
      await nextTick();

      expect(findAiCatalogList().props('search')).toBe(searchTerm);

      // Clear the search
      findFilteredSearch().vm.$emit('clear');
      expect(wrapper.emitted('clear-search')).toHaveLength(1);
      await nextTick();

      expect(findAiCatalogList().props('search')).toBe('');
    });

    it('updates filteredSearchValue when searchTerm changes', async () => {
      setSearch();

      await nextTick();

      expect(findFilteredSearch().props('value')).toEqual([
        {
          type: 'filtered-search-term',
          value: { data: searchTerm },
        },
      ]);
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to AiCatalogList', () => {
      expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('emits next-page event when AiCatalogList emits next-page', () => {
      findAiCatalogList().vm.$emit('next-page');

      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });

    it('emits prev-page event when AiCatalogList emits prev-page', () => {
      findAiCatalogList().vm.$emit('prev-page');

      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });
  });

  describe('loading state', () => {
    it('passes loading state to AiCatalogList', () => {
      createComponent({ props: { isLoading: true } });

      expect(findAiCatalogList().props('isLoading')).toBe(true);
    });

    it('passes false loading state to AiCatalogList', () => {
      createComponent({ props: { isLoading: false } });

      expect(findAiCatalogList().props('isLoading')).toBe(false);
    });
  });

  describe('empty state props', () => {
    it('passes all empty state props to AiCatalogList', () => {
      createComponent();
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
      });
    });

    it('uses fallback text when no empty state props are passed', () => {
      createComponent({
        props: {
          emptyStateTitle: undefined,
          emptyStateDescription: undefined,
          emptyStateButtonHref: undefined,
          emptyStateButtonText: undefined,
        },
      });
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        emptyStateTitle: 'Get started with the AI Catalog',
        emptyStateDescription:
          'Build agents and flows to automate tasks and solve complex problems.',
        emptyStateButtonHref: null,
        emptyStateButtonText: null,
      });
    });
  });
});
