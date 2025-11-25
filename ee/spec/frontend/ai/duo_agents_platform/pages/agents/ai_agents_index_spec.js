import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTabs, GlTab } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiAgentsIndex from 'ee/ai/duo_agents_platform/pages/agents/ai_agents_index.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import aiCatalogGroupUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_group_user_permissions.query.graphql';
import aiCatalogProjectUserPermissionsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import projectAiCatalogAgentsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_agents.query.graphql';
import {
  mockAgentsWithConfig,
  mockPageInfo,
  mockGroupUserPermissionsResponse,
  mockProjectUserPermissionsResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockConfiguredItemsEmptyResponse,
} from 'ee_jest/ai/catalog/mock_data';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import { mockProjectAgentsResponse, mockProjectItemsEmptyResponse } from '../../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiAgentsIndex', () => {
  let wrapper;
  let mockApollo;

  const mockRouter = {
    push: jest.fn(),
  };
  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockProjectPath = '/mock-group/test-project';
  const mockConfiguredItemsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockConfiguredItemsEmptyResponse);
  const mockProjectAgentsQueryHandler = jest.fn().mockResolvedValue(mockProjectAgentsResponse);
  const mockGroupUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockGroupUserPermissionsResponse);
  const mockProjectUserPermissionsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectUserPermissionsResponse);
  const createAiCatalogItemConsumerHandler = jest.fn();

  const createComponent = ({ provide = {} } = {}) => {
    mockApollo = createMockApollo([
      [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
      [projectAiCatalogAgentsQuery, mockProjectAgentsQueryHandler],
      [aiCatalogGroupUserPermissionsQuery, mockGroupUserPermissionsQueryHandler],
      [aiCatalogProjectUserPermissionsQuery, mockProjectUserPermissionsQueryHandler],
      [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
    ]);

    wrapper = shallowMountExtended(AiAgentsIndex, {
      apolloProvider: mockApollo,
      provide: {
        projectId: mockProjectId,
        projectPath: mockProjectPath,
        exploreAiCatalogPath: '/explore/ai-catalog',
        ...provide,
      },
      mocks: {
        $router: mockRouter,
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
  const findAiCatalogList = () => wrapper.findByTestId('managed-agents-list');
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findTabs = () => wrapper.findComponent(GlTabs);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogListHeader component', () => {
      expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
    });

    it('renders AiCatalogConfiguredItemsWrapper with correct props', () => {
      expect(findConfiguredItemsWrapper().props()).toMatchObject({
        emptyStateTitle: 'Use agents in your project.',
        emptyStateDescription: 'Use agents to automate tasks and answer questions.',
        emptyStateButtonHref: '/explore/ai-catalog/agents',
        emptyStateButtonText: 'Explore the AI Catalog',
        itemTypes: ['AGENT'],
      });
    });
  });

  describe('when "Managed" tab is selected', () => {
    beforeEach(() => {
      mockProjectAgentsQueryHandler.mockResolvedValue(mockProjectAgentsResponse);
      createComponent();
      findTabs().vm.$emit('input', 1);
    });

    it('renders AiCatalogList component', async () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual(mockAgentsWithConfig);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    it('fetches list data', () => {
      expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        projectPath: mockProjectPath,
        allAvailable: false,
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
        expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
      });

      it('refetches query with correct variables when paging backward', async () => {
        findAiCatalogList().vm.$emit('prev-page');
        await nextTick();
        expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
          projectId: `gid://gitlab/Project/${mockProjectId}`,
          projectPath: mockProjectPath,
          allAvailable: false,
          after: null,
          before: 'eyJpZCI6IjUxIn0',
          first: null,
          last: 20,
        });
      });

      it('refetches query with correct variables when paging forward', async () => {
        findAiCatalogList().vm.$emit('next-page');
        await nextTick();
        expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith({
          projectId: `gid://gitlab/Project/${mockProjectId}`,
          projectPath: mockProjectPath,
          allAvailable: false,
          after: 'eyJpZCI6IjM1In0',
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('when there are no agents', () => {
      beforeEach(async () => {
        mockProjectAgentsQueryHandler.mockResolvedValueOnce(mockProjectItemsEmptyResponse);

        await waitForPromises();
      });

      it('renders empty state with correct props', () => {
        expect(findEmptyState().props()).toMatchObject({
          title: 'Use agents in your project.',
          description: 'Use agents to automate tasks and answer questions.',
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

    describe('adding an agent to project', () => {
      const input = {
        itemId: 'gid://gitlab/Ai::Catalog::Item/1',
        itemName: 'Test Agent',
        parentItemConsumerId: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
      };
      const addAgentToProject = () => findAddProjectItemConsumerModal().vm.$emit('submit', input);

      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          createAiCatalogItemConsumerHandler.mockResolvedValue(
            mockAiCatalogItemConsumerCreateSuccessProjectResponse,
          );

          addAgentToProject();
          await waitForPromises();
        });

        it('shows a toast message', () => {
          expect(mockToast.show).toHaveBeenCalledWith('Agent enabled in Test.');
        });

        it('calls the mutation with correct variables', () => {
          expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
            input: {
              itemId: input.itemId,
              parentItemConsumerId: input.parentItemConsumerId,
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

          addAgentToProject();
          await waitForPromises();

          expect(findErrorsAlert().props()).toMatchObject({
            title: 'Agent "Test Agent" could not be enabled.',
            errors: ['Item already configured.'],
          });
        });
      });

      describe('when request fails', () => {
        it('shows alert with error and captures exception', async () => {
          createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('Request failed'));

          addAgentToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([
            'Could not enable agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  });
});
