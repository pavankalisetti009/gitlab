import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogAgent from 'ee/ai/catalog/pages/ai_catalog_agent.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import {
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentNullResponse,
  mockAgent,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockAgentVersion,
  mockAgentPinnedVersion,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = {
  name: 'RouterViewStub',
  props: ['aiCatalogAgent', 'version', 'hasParentConsumer'],
  template: '<div />',
};

describe('AiCatalogAgent', () => {
  let wrapper;
  let mockApollo;
  const agentId = 1;
  const routeParams = { id: agentId };

  const mockAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);
  const mockAgentNullQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentNullResponse);

  const createComponent = ({ agentQueryHandler = mockAgentQueryHandler, provide = {} } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentQuery, agentQueryHandler]]);

    wrapper = shallowMount(AiCatalogAgent, {
      apolloProvider: mockApollo,
      provide,
      mocks: {
        $route: {
          params: routeParams,
        },
      },
      stubs: {
        RouterView: RouterViewStub,
      },
    });
  };

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRouterView = () => wrapper.findComponent(RouterViewStub);

  beforeEach(() => {
    createComponent({
      provide: { projectId: 1 },
    });
  });

  it('renders loading icon while fetching data', async () => {
    expect(findGlLoadingIcon().exists()).toBe(true);

    await waitForPromises();

    expect(findGlLoadingIcon().exists()).toBe(false);
  });

  describe('when request succeeds but returns null', () => {
    beforeEach(async () => {
      createComponent({ agentQueryHandler: mockAgentNullQueryHandler });
      await waitForPromises();
    });

    it('renders empty state', () => {
      expect(findGlEmptyState().exists()).toBe(true);
      expect(findGlEmptyState().props('title')).toBe('Agent not found.');
    });

    it('does not render router view', () => {
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('when request succeeds', () => {
    beforeEach(async () => {
      createComponent({
        provide: { projectId: 1, rootGroupId: '1' },
      });
      await waitForPromises();
    });

    it('does not render empty state', () => {
      expect(findGlEmptyState().exists()).toBe(false);
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
      expect(findRouterView().props('aiCatalogAgent')).toEqual({
        ...mockAgent,
        configurationForProject: mockAgentConfigurationForProject,
        configurationForGroup: mockItemConfigurationForGroup,
      });
    });
  });

  describe('when displaying soft-deleted agents', () => {
    it('should show soft-deleted agents in the Projects area', async () => {
      createComponent({
        provide: { projectId: 1, rootGroupId: '1' },
      });
      await waitForPromises();

      expect(mockAgentQueryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::Item/1',
        showSoftDeleted: true,
        hasProject: true,
        projectId: 'gid://gitlab/Project/1',
        hasGroup: true,
        groupId: 'gid://gitlab/Group/1',
      });
    });

    it('should not show soft-deleted agents in the explore area', async () => {
      createComponent({
        provide: { isGlobal: true }, // "Projects" area is not global, "Explore" is
      });
      await waitForPromises();

      expect(mockAgentQueryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::Item/1',
        showSoftDeleted: false,
        hasProject: false,
        projectId: 'gid://gitlab/Project/0',
        hasGroup: false,
        groupId: 'gid://gitlab/Group/0',
      });
    });
  });

  describe('when request fails', () => {
    const error = new Error('Request failed');

    beforeEach(async () => {
      createComponent({ agentQueryHandler: jest.fn().mockRejectedValue(error) });
      await waitForPromises();
    });

    it('does not render router view', () => {
      expect(findRouterView().exists()).toBe(false);
    });

    it('renders empty state', () => {
      expect(findGlEmptyState().exists()).toBe(true);
    });

    it('renders and captures error', () => {
      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().props('errors')).toEqual(['Agent does not exist']);
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('when displaying different agent versions', () => {
    it('should show latest version when in the explore area', async () => {
      createComponent({
        provide: { isGlobal: true },
      });
      await waitForPromises();

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
      });
    });

    it('should show pinned version when in the group area', async () => {
      createComponent({
        provide: { groupId: 1, projectId: null },
      });
      await waitForPromises();

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
      });
    });

    it('should show pinned version when in project area', async () => {
      createComponent({
        provide: { projectId: 1 },
      });
      await waitForPromises();

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
      });
    });
  });

  describe('when itemType is not AGENT', () => {
    it('renders agent not found', async () => {
      const mockFlowResponse = {
        data: {
          aiCatalogItem: {
            ...mockAgent,
            itemType: 'FLOW',
          },
        },
      };
      createComponent({
        agentQueryHandler: jest.fn().mockResolvedValue(mockFlowResponse),
      });

      await waitForPromises();

      expect(findGlEmptyState().exists()).toBe(true);
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('version update behaviour', () => {
    const mockHandlerFactory = ({ configurationForProject = {}, permission = {} }) => {
      return jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem: {
            ...mockAgent,
            configurationForProject: {
              ...mockAgentConfigurationForProject,
              ...configurationForProject,
              userPermissions: {
                ...(configurationForProject.userPermissions ??
                  mockAgentConfigurationForProject.userPermissions),
                ...permission,
              },
            },
          },
        },
      });
    };

    describe('when viewing explore and group areas', () => {
      const mockHandler = mockHandlerFactory({
        permission: {
          adminAiCatalogItemConsumer: true, // negative test to ensure that despite being allowed to, the update is still not shown
        },
      });

      it('does not show update alert when in explore area', async () => {
        createComponent({
          agentQueryHandler: mockHandler,
          provide: { isGlobal: true },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(false);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_LATEST);
      });

      it('does not show update alert when in group area', async () => {
        createComponent({
          provide: { isGlobal: false, projectId: null },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(false);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_LATEST);
      });
    });

    describe('when viewing project area', () => {
      it('should show update alert when a new version is available and user has permissions', async () => {
        const mockHandler = mockHandlerFactory({
          permission: { adminAiCatalogItemConsumer: true },
        });
        createComponent({
          agentQueryHandler: mockHandler,
          provide: { projectId: 1 },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(true);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_PINNED);
      });

      it('should not show update alert when a new version is available but user does not have permissions', async () => {
        const mockHandler = mockHandlerFactory({
          permission: { adminAiCatalogItemConsumer: false },
        });
        createComponent({
          agentQueryHandler: mockHandler,
          provide: { projectId: 1 },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(false);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_PINNED);
      });

      it('should not show update alert when no new version is available', async () => {
        const mockHandler = mockHandlerFactory({
          configurationForProject: {
            pinnedItemVersion: {
              ...mockAgentPinnedVersion,
              id: 'asd',
              humanVersionName: mockAgentVersion.humanVersionName, // Same as latest
            },
          },
          permission: { adminAiCatalogItemConsumer: true },
        });
        createComponent({
          agentQueryHandler: mockHandler,
          provide: { projectId: 1 },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(false);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_PINNED);
      });
    });
  });

  describe.each`
    hasParentConsumer | configurationForGroupEnabled
    ${true}           | ${true}
    ${false}          | ${false}
  `(
    'when configurationForGroup.enabled is $configurationForGroupEnabled',
    ({ hasParentConsumer, configurationForGroupEnabled }) => {
      beforeEach(async () => {
        const mockAgentGroupConfigQueryHandler = jest.fn().mockResolvedValue({
          data: {
            aiCatalogItem: {
              ...mockAgent,
              configurationForProject: mockAgentConfigurationForProject,
              configurationForGroup: {
                ...mockItemConfigurationForGroup,
                enabled: configurationForGroupEnabled,
              },
            },
          },
        });
        createComponent({
          provide: { projectId: 1, rootGroupId: '1' },
          agentQueryHandler: mockAgentGroupConfigQueryHandler,
        });
        await waitForPromises();
        await nextTick();
      });

      it(`passes ${hasParentConsumer} hasParentConsumer to router view`, () => {
        expect(findRouterView().exists()).toBe(true);
        expect(findRouterView().props('hasParentConsumer')).toBe(hasParentConsumer);
      });
    },
  );
});
