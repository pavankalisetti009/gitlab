import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTabs, GlTab } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiFlowsIndex from 'ee/ai/duo_agents_platform/pages/flows/ai_flows_index.vue';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import projectAiCatalogFlowsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_flows.query.graphql';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockConfiguredItemsEmptyResponse,
  mockGroupUserPermissionsResponse,
  mockProjectUserPermissionsResponse,
  mockFlows,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';
import { mockProjectFlowsResponse, mockProjectItemsEmptyResponse } from '../../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiFlowsIndex', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockProjectPath = 'test-group/test-project';
  const mockConfiguredItemsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockConfiguredItemsEmptyResponse);
  const mockGroupUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockGroupUserPermissionsResponse);
  const mockProjectUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsResponse);
  const createAiCatalogItemConsumerHandler = jest.fn();
  const mockProjectFlowsQueryHandler = jest.fn().mockResolvedValue(mockProjectFlowsResponse);

  const defaultProvide = {
    projectId: mockProjectId,
    projectPath: mockProjectPath,
    exploreAiCatalogPath: '/explore/ai-catalog',
    glFeatures: {
      aiCatalogFlows: true,
      aiCatalogThirdPartyFlows: true,
    },
  };

  const createComponent = ({ provide = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
      [aiCatalogProjectUserPermissionsQuery, mockProjectUserPermissionsQueryHandler],
      [aiCatalogGroupUserPermissionsQuery, mockGroupUserPermissionsQueryHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
      [projectAiCatalogFlowsQuery, mockProjectFlowsQueryHandler],
    ]);

    wrapper = shallowMountExtended(AiFlowsIndex, {
      apolloProvider: mockApollo,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $toast: mockToast,
      },
      stubs: {
        GlTab,
        AiCatalogConfiguredItemsWrapper,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findConfiguredItemsWrapper = () => wrapper.findComponent(AiCatalogConfiguredItemsWrapper);
  const findAddProjectItemConsumerModal = () => wrapper.findComponent(AddProjectItemConsumerModal);
  const findAiCatalogListWrapper = () => wrapper.findByTestId('managed-flows-list');
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findTabs = () => wrapper.findComponent(GlTabs);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('renders AiCatalogConfiguredItemsWrapper component with correct props', () => {
      expect(findConfiguredItemsWrapper().props()).toMatchObject({
        emptyStateTitle: 'Use flows in your project.',
        emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
        emptyStateButtonHref: '/explore/ai-catalog/flows',
        emptyStateButtonText: 'Explore the AI Catalog',
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
      });
    });
  });

  describe('when "Managed" tab is selected', () => {
    beforeEach(() => {
      createComponent();
      findTabs().vm.$emit('input', 1);
    });

    it('renders AiCatalogList component', async () => {
      const catalogList = findAiCatalogListWrapper();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual(mockFlows);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    it('fetches list data', () => {
      expect(mockProjectFlowsQueryHandler).toHaveBeenCalledWith({
        projectPath: mockProjectPath,
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        allAvailable: false,
        search: '',
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });

    describe('pagination', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('passes pageInfo to list component', () => {
        expect(findAiCatalogListWrapper().props('pageInfo')).toMatchObject(mockPageInfo);
      });

      it('refetches query with correct variables when paging backward', async () => {
        findAiCatalogListWrapper().vm.$emit('prev-page');
        await nextTick();
        expect(mockProjectFlowsQueryHandler).toHaveBeenCalledWith({
          projectPath: mockProjectPath,
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          search: '',
          allAvailable: false,
          after: null,
          before: 'eyJpZCI6IjUxIn0',
          first: null,
          last: 20,
        });
      });

      it('refetches query with correct variables when paging forward', async () => {
        findAiCatalogListWrapper().vm.$emit('next-page');
        await nextTick();
        expect(mockProjectFlowsQueryHandler).toHaveBeenCalledWith({
          projectPath: mockProjectPath,
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          search: '',
          allAvailable: false,
          after: 'eyJpZCI6IjM1In0',
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('search functionality', () => {
      beforeEach(async () => {
        await waitForPromises();
      });

      it('refetches query with search term when search is submitted', async () => {
        findAiCatalogListWrapper().vm.$emit('search', ['test flow']);
        await nextTick();

        expect(mockProjectFlowsQueryHandler).toHaveBeenCalledWith({
          projectPath: mockProjectPath,
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          allAvailable: false,
          search: 'test flow',
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });

      it('clears search term when clear-search is emitted', async () => {
        // First set a search term
        findAiCatalogListWrapper().vm.$emit('search', ['test flow']);
        await nextTick();

        // Then clear it
        findAiCatalogListWrapper().vm.$emit('clear-search');
        await nextTick();

        expect(mockProjectFlowsQueryHandler).toHaveBeenLastCalledWith({
          projectPath: mockProjectPath,
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          allAvailable: false,
          search: '',
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('when there are no flows', () => {
      beforeEach(async () => {
        mockProjectFlowsQueryHandler.mockResolvedValueOnce(mockProjectItemsEmptyResponse);

        await waitForPromises();
      });

      it('renders empty state with correct props', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Use flows in your project.',
          description: 'Flows use multiple agents to complete tasks automatically.',
        });
      });
    });
  });

  describe('Apollo queries', () => {
    describe('when in project namespace', () => {
      beforeEach(() => {
        createComponent();
      });

      it('fetches project user permissions', () => {
        expect(mockProjectUserPermissionsQueryHandler).toHaveBeenCalledWith({
          fullPath: mockProjectPath,
        });
      });

      it('skips group user permissions query', () => {
        expect(mockGroupUserPermissionsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('when in group namespace', () => {
      const mockGroupId = 2;
      const mockGroupPath = 'test-group';

      beforeEach(() => {
        createComponent({
          provide: {
            groupId: mockGroupId,
            groupPath: mockGroupPath,
            projectId: null,
            projectPath: null,
          },
        });
      });

      it('fetches group user permissions', () => {
        expect(mockGroupUserPermissionsQueryHandler).toHaveBeenCalledWith({
          fullPath: mockGroupPath,
        });
      });

      it('skips project user permissions query', () => {
        expect(mockProjectUserPermissionsQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('adding a flow to project', () => {
      const input = {
        itemId: 'gid://gitlab/Ai::Catalog::Item/1',
        itemName: 'Test Flow',
        parentItemConsumerId: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
        triggerTypes: ['mention'],
      };
      const addFlowToProject = () => findAddProjectItemConsumerModal().vm.$emit('submit', input);

      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          createAiCatalogItemConsumerHandler.mockResolvedValue(
            mockAiCatalogItemConsumerCreateSuccessProjectResponse,
          );

          addFlowToProject();
          await waitForPromises();
        });

        it('shows a toast message', () => {
          expect(mockToast.show).toHaveBeenCalledWith('Flow enabled in Test.');
        });

        it('calls the mutation with correct variables', () => {
          expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
            input: {
              itemId: input.itemId,
              parentItemConsumerId: input.parentItemConsumerId,
              triggerTypes: input.triggerTypes,
              target: {
                projectId: `gid://gitlab/Project/${mockProjectId}`,
              },
            },
          });
        });

        it('refetches aiCatalogConfiguredItemsQuery', () => {
          expect(mockConfiguredItemsQueryHandler).toHaveBeenCalled();
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows alert with error', async () => {
          createAiCatalogItemConsumerHandler.mockResolvedValue(
            mockAiCatalogItemConsumerCreateErrorResponse,
          );

          addFlowToProject();
          await waitForPromises();

          expect(findErrorsAlert().props()).toMatchObject({
            title: 'Flow "Test Flow" could not be enabled.',
            errors: ['Item already configured.'],
          });
        });
      });

      describe('when request fails', () => {
        it('shows alert with error and captures exception', async () => {
          createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('Request failed'));

          addFlowToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([
            'Could not enable flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('handles error event from wrapper component', async () => {
      const errorPayload = {
        title: 'Failed to disable flow',
        errors: ['Some error message'],
      };

      await findConfiguredItemsWrapper().vm.$emit('error', errorPayload);

      expect(findErrorsAlert().props('title')).toBe('Failed to disable flow');
      expect(findErrorsAlert().props('errors')).toEqual(['Some error message']);
    });
  });
});
