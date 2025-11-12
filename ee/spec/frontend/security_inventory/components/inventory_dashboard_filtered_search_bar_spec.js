import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { queryToObject } from '~/lib/utils/url_utility';
import { toolCoverageTokens } from 'ee/security_inventory/components/tool_coverage_tokens';
import { vulnerabilityCountTokens } from 'ee/security_inventory/components/vulnerability_count_tokens';
import { mockAnalyzerFilter, mockVulnerabilityFilter } from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  queryToObject: jest.fn().mockReturnValue({}),
  setUrlParams: jest.fn().mockReturnValue(''),
}));

describe('InventoryDashboardFilteredSearchBar', () => {
  let wrapper;

  const createComponent = ({ props = {}, securityInventoryFiltering = true } = {}) => {
    wrapper = shallowMount(InventoryDashboardFilteredSearchBar, {
      provide: {
        glFeatures: {
          securityInventoryFiltering,
        },
      },
      propsData: {
        namespace: 'group1',
        ...props,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);

  const emptyFilters = {
    securityAnalyzerFilters: [],
    vulnerabilityCountFilters: [],
    attributeFilters: [],
  };

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the filtered search component', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('passes the correct props to filtered search', () => {
      expect(findFilteredSearch().props()).toMatchObject({
        initialFilterValue: [],
        tokens: [...vulnerabilityCountTokens, ...toolCoverageTokens],
        termsAsTokens: true,
      });
    });

    it('has no tokens when filtering feature flag is disabled', () => {
      createComponent({ securityInventoryFiltering: false });

      expect(findFilteredSearch().props('tokens')).toStrictEqual([]);
    });
  });

  describe('initialFilterValue', () => {
    it('use initialFilters prop when search is provided', () => {
      createComponent({
        props: {
          initialFilters: { search: 'test-search' },
        },
      });
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(['test-search']);
    });

    it('use URL search parameter when available and initialFilters is not provided', () => {
      queryToObject.mockReturnValue({ search: 'url-search' });
      createComponent();
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(['url-search']);
    });

    it('returns empty array when no search is available', () => {
      queryToObject.mockReturnValue({});
      createComponent();
      expect(findFilteredSearch().props('initialFilterValue')).toEqual([]);
    });
  });

  describe('onFilter method', () => {
    it('emits filterSubgroupsAndProjects event with search param when filtered with text', async () => {
      const searchTerm = 'test project';
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: searchTerm },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      filters[0].search = searchTerm;
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: searchTerm,
        ...emptyFilters,
      });
    });

    it('emits filterSubgroupsAndProjects event with combined search terms when multiple terms are provided', async () => {
      const searchTerms = ['test', 'project'];
      const filters = searchTerms.map((term) => ({
        type: 'filtered-search-term',
        value: { data: term },
      }));
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test project',
        ...emptyFilters,
      });
    });

    it('emits filterSubgroupsAndProjects event without search when no search terms are provided', async () => {
      findFilteredSearch().vm.$emit('onFilter', []);
      await nextTick();
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        ...emptyFilters,
      });
    });

    it('emits filterSubgroupsAndProjects with vulnerability count filter', async () => {
      const filters = [
        {
          id: 'token-1',
          type: 'critical',
          value: { operator: '=', data: '0' },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        securityAnalyzerFilters: [],
        vulnerabilityCountFilters: [mockVulnerabilityFilter],
        attributeFilters: [],
      });
    });

    it('emits filterSubgroupsAndProjects with tool coverage filter', async () => {
      const filters = [
        {
          id: 'token-2',
          type: 'SAST_ADVANCED',
          value: { operator: '=', data: 'NOT_CONFIGURED' },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        securityAnalyzerFilters: [mockAnalyzerFilter],
        vulnerabilityCountFilters: [],
        attributeFilters: [],
      });
    });

    it('emits filterSubgroupsAndProjects with attribute filter', async () => {
      const filters = [
        {
          type: 'attribute-token-location',
          value: {
            operator: '||',
            data: ['gid://gitlab/Security::Attribute/6', 'gid://gitlab/Security::Attribute/7'],
          },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        securityAnalyzerFilters: [],
        vulnerabilityCountFilters: [],
        attributeFilters: [
          {
            operator: 'IS_ONE_OF',
            attributes: [
              'gid://gitlab/Security::Attribute/6',
              'gid://gitlab/Security::Attribute/7',
            ],
          },
        ],
      });
    });

    it('skips filters without value data', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'filtered-search-term',
          value: {},
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test search',
        ...emptyFilters,
      });
    });

    it('ignores non-text filter types', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'other-type',
          value: { data: 'should be ignored' },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test search',
        ...emptyFilters,
      });
    });
  });
});
