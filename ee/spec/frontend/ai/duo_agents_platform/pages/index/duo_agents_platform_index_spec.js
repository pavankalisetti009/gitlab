import { shallowMount } from '@vue/test-utils';
import { GlExperimentBadge } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';

import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

import waitForPromises from 'helpers/wait_for_promises';
import { mockAgentFlowsResponse } from '../../../mocks';

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

    const expectQueryVariablesUpdatedEvent = (expectedPayload) => {
      const emittedEvents = wrapper.emitted('query-variables-updated');
      expect(emittedEvents).toHaveLength(2);
      expect(emittedEvents[1]).toEqual([expectedPayload]);
    };

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

      expect(tokens).toHaveLength(2);

      expect(tokens[0]).toMatchObject({
        type: 'flow-name',
        title: 'Flow',
        icon: 'flow-ai',
        unique: true,
      });
      expect(tokens[0].options).toEqual([
        { value: 'code_review/v1', title: 'Code review' },
        { value: 'convert_to_gitlab_ci', title: 'Convert to gitlab ci' },
        { value: 'fix_pipeline/v1', title: 'Fix pipeline' },
        { value: 'issue_to_merge_request', title: 'Issue to merge request' },
        { value: 'software_development', title: 'Software development' },
      ]);

      expect(tokens[1]).toMatchObject({
        type: 'flow-status-group',
        title: 'Status',
        icon: 'status',
        unique: true,
      });
      expect(tokens[1].options).toEqual([
        { value: 'ACTIVE', title: 'Active' },
        { value: 'PAUSED', title: 'Paused' },
        { value: 'AWAITING_INPUT', title: 'Awaiting input' },
        { value: 'COMPLETED', title: 'Completed' },
        { value: 'FAILED', title: 'Failed' },
        { value: 'CANCELED', title: 'Canceled' },
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
      it('emits query-variables-updated event when onSort is triggered', () => {
        findFilteredSearchBar().vm.$emit('onSort', 'UPDATED_DESC');

        expectQueryVariablesUpdatedEvent({
          sort: 'UPDATED_DESC',
          pagination: { before: null, after: null, first: 20, last: null },
          filters: {},
        });
      });
    });

    describe('when filtering', () => {
      describe('with valid flow-name token', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'flow-name', value: { data: 'convert_to_gitlab_ci' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { type: 'convert_to_gitlab_ci' },
          });
        });
      });

      describe('with valid flow-status-group token', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'flow-status-group', value: { data: 'PAUSED' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { statusGroup: 'PAUSED' },
          });
        });
      });

      describe('with unsupported free text search', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'filtered-search-term', value: { data: 'software dev' } }];

          findFilteredSearchBar().vm.$emit('onFilter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { search: 'software dev' },
          });
        });
      });

      describe('when filters are cleared', () => {
        it('emits query-variables-updated event with empty filters', () => {
          findFilteredSearchBar().vm.$emit('onFilter', []);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: {},
          });
        });
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when next page is requested', () => {
      it('emits query-variables-updated event with correct parameters', () => {
        findWorkflowsList().vm.$emit('next-page');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: {
                before: null,
                after: 'asdf',
                first: 20,
                last: null,
              },
              filters: {},
            },
          ],
        ]);
      });
    });

    describe('when previous page is requested', () => {
      it('emits query-variables-updated event with correct parameters', () => {
        findWorkflowsList().vm.$emit('prev-page');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: {
                after: null,
                before: 'asdf',
                first: null,
                last: 20,
              },
              filters: {},
            },
          ],
        ]);
      });
    });
  });
});
