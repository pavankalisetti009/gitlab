import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlExperimentBadge } from '@gitlab/ui';
import { nextTick } from 'vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

import waitForPromises from 'helpers/wait_for_promises';

import { mockAgentFlowsResponse } from '../../../mocks';

jest.mock('~/alert');

describe('AgentsPlatformIndex', () => {
  let wrapper;

  const defaultProps = {
    initialSort: 'UPDATED_DESC',
    hasInitialWorkflows: true,
    isLoadingWorkflows: false,
    workflows: mockAgentFlowsResponse.data.project.duoWorkflowWorkflows.edges.map(
      (edge) => edge.node,
    ),
    workflowsPageInfo: { startCursor: 'asdf', endCursor: 'asdf' },
  };

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMount(AgentsPlatformIndex, {
      propsData: { ...defaultProps, ...props },
      provide: {
        isSidePanelView: false,
        ...provide,
      },
    });

    return waitForPromises();
  };

  const findWorkflowsList = () => wrapper.findComponent(AgentFlowList);
  const findLoadingIcon = () => wrapper.find('[data-testid="loading-container"]');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findAlert = () => wrapper.findComponent(GlAlert);

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('when not in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: false } });
    });

    it('loads the page heading and experiment badge', () => {
      expect(findPageHeading().exists()).toBe(true);
      expect(findPageHeading().text()).toContain('Sessions');

      expect(findExperimentBadge().exists()).toBe(true);
      expect(findExperimentBadge().props('type')).toBe('beta');
    });
  });

  describe('when in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: true } });
    });

    it('does not render the page heading', () => {
      expect(findPageHeading().exists()).toBe(false);
    });
  });

  describe('when loading the queries', () => {
    beforeEach(() => {
      createWrapper({ props: { isLoadingWorkflows: true } });
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the workflow list', () => {
      expect(findWorkflowsList().exists()).toBe(false);
    });
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the workflows list component', () => {
      expect(findWorkflowsList().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('passes correct props to AgentFlowList', () => {
      expect(findWorkflowsList().props()).toMatchObject({
        showProjectInfo: false,
        showEmptyState: false,
        workflows: expect.any(Array),
        workflowsPageInfo: expect.any(Object),
      });
    });
  });

  describe('filtering and sorting', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the filtered search bar with correct props', () => {
      expect(findFilteredSearchBar().exists()).toBe(true);
      expect(findFilteredSearchBar().props()).toMatchObject({
        namespace: 'duo-agents-platform',
        searchInputPlaceholder: 'Search for a session',
        syncFilterAndSort: true,
        termsAsTokens: true,
        initialSortBy: 'UPDATED_DESC',
      });
    });

    it('renders the filtered search bar with sort options', () => {
      expect(findFilteredSearchBar().props('sortOptions')).toEqual([
        {
          id: 1,
          title: 'Created date',
          sortDirection: {
            descending: 'CREATED_DESC',
            ascending: 'CREATED_ASC',
          },
        },
        {
          id: 2,
          title: 'Updated date',
          sortDirection: {
            descending: 'UPDATED_DESC',
            ascending: 'UPDATED_ASC',
          },
        },
      ]);
    });

    it('renders the filtered search bar with filter tokens', () => {
      const tokens = findFilteredSearchBar().props('tokens');

      expect(tokens).toHaveLength(1);

      expect(tokens[0]).toMatchObject({
        type: 'flow-name',
        title: 'Flow Name',
        icon: 'flow-ai',
        unique: true,
      });
      expect(tokens[0].options).toEqual([
        { value: 'software_development', title: 'Software Development' },
        { value: 'convert_to_gitlab_ci', title: 'Convert to gitlab ci' },
      ]);
    });

    describe('when hasInitialWorkflows is false', () => {
      beforeEach(async () => {
        await createWrapper({ props: { hasInitialWorkflows: false } });
      });

      it('does not render the filtered search bar', () => {
        expect(findFilteredSearchBar().exists()).toBe(false);
      });
    });

    describe('when sorting', () => {
      it('emits update-sort event when onSort is triggered', () => {
        findFilteredSearchBar().vm.$emit('onSort', 'UPDATED_DESC');

        expect(wrapper.emitted('update-sort')).toEqual([['UPDATED_DESC']]);
      });
    });

    describe('when filtering', () => {
      describe('with valid flow-name token', () => {
        it('emits update-filters event with processed filter parameters', () => {
          const filters = [{ type: 'flow-name', value: { data: 'convert_to_gitlab_ci' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);

          expect(wrapper.emitted('update-filters')).toEqual([[{ type: 'convert_to_gitlab_ci' }]]);
        });

        it('hides alert when valid filters are applied', () => {
          const filters = [{ type: 'flow-name', value: { data: 'software_development' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);

          expect(findAlert().exists()).toBe(false);
        });
      });

      describe('with unsupported free text search', () => {
        it('shows alert and does not emit update-filters', async () => {
          const filters = [{ type: 'filtered-search-term', value: { data: 'software dev' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);
          await nextTick();

          expect(findAlert().exists()).toBe(true);
          expect(findAlert().props('variant')).toBe('warning');
          expect(findAlert().text()).toContain('Raw text search is not currently supported');
          expect(wrapper.emitted('update-filters')).toBeUndefined();
        });
      });

      describe('when filters are cleared', () => {
        it('emits update-filters event with empty filters', () => {
          findFilteredSearchBar().vm.$emit('onFilter', []);

          expect(wrapper.emitted('update-filters')).toEqual([[{}]]);
        });
      });
    });

    describe('alert dismissal', () => {
      beforeEach(() => {
        // Trigger alert by using unsupported search
        const filters = [{ type: 'filtered-search-term', value: { data: 'test' } }];
        findFilteredSearchBar().vm.$emit('onFilter', filters);
      });

      it('hides alert when dismissed', async () => {
        expect(findAlert().exists()).toBe(true);

        findAlert().vm.$emit('dismiss');
        await nextTick();

        expect(findAlert().exists()).toBe(false);
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when next page is requested', () => {
      it('emits update-pagination event with correct parameters', () => {
        findWorkflowsList().vm.$emit('next-page');

        expect(wrapper.emitted('update-pagination')).toEqual([
          [
            {
              before: null,
              after: 'asdf',
              first: 20,
              last: null,
            },
          ],
        ]);
      });
    });

    describe('when previous page is requested', () => {
      it('emits update-pagination event with correct parameters', () => {
        findWorkflowsList().vm.$emit('prev-page');

        expect(wrapper.emitted('update-pagination')).toEqual([
          [
            {
              after: null,
              before: 'asdf',
              first: null,
              last: 20,
            },
          ],
        ]);
      });
    });
  });
});
