import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogFlow from 'ee/ai/catalog/pages/ai_catalog_flow.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import {
  mockAiCatalogFlowResponse,
  mockAiCatalogFlowNullResponse,
  mockFlow,
  mockFlowPinnedVersion,
  mockFlowVersion,
  mockFlowConfigurationForProject,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = Vue.extend({
  name: 'RouterViewStub',
  // eslint-disable-next-line vue/require-prop-types
  props: ['aiCatalogFlow', 'version'],
  template: '<div />',
});

describe('AiCatalogFlow', () => {
  let wrapper;
  let mockApollo;
  const flowId = 1;
  const routeParams = { id: flowId };

  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockFlowNullQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowNullResponse);

  const createComponent = ({ flowQueryHandler = mockFlowQueryHandler, provide = {} } = {}) => {
    mockApollo = createMockApollo([[aiCatalogFlowQuery, flowQueryHandler]]);

    wrapper = shallowMount(AiCatalogFlow, {
      apolloProvider: mockApollo,
      provide,
      mocks: {
        $route: {
          params: routeParams,
        },
      },
      stubs: {
        'router-view': RouterViewStub,
      },
    });
  };

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRouterView = () => wrapper.findComponent(RouterViewStub);

  it('renders loading icon while fetching data', async () => {
    createComponent();
    expect(findGlLoadingIcon().exists()).toBe(true);

    await waitForPromises();
    expect(findGlLoadingIcon().exists()).toBe(false);
  });

  describe('when request succeeds but returns null', () => {
    beforeEach(async () => {
      createComponent({ flowQueryHandler: mockFlowNullQueryHandler });
      await waitForPromises();
    });

    it('renders empty state', () => {
      expect(findGlEmptyState().exists()).toBe(true);
      expect(findGlEmptyState().props('title')).toBe('Flow not found.');
    });

    it('does not render router view', () => {
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('when request succeeds', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not render empty state', () => {
      expect(findGlEmptyState().exists()).toBe(false);
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
      expect(findRouterView().props('aiCatalogFlow')).toEqual(mockFlow);
    });
  });

  describe('when displaying soft-deleted flows', () => {
    it('should show soft-deleted flows in the Projects area', () => {
      createComponent({
        provide: {
          projectId: '200',
          rootGroupId: 1,
        },
      });

      expect(mockFlowQueryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::Item/1',
        showSoftDeleted: true,
        hasProject: true,
        projectId: 'gid://gitlab/Project/200',
        hasGroup: true,
        groupId: 'gid://gitlab/Group/1',
      });
    });

    it('should not show soft-deleted flows in the explore area', () => {
      createComponent({
        provide: { isGlobal: true }, // "Projects" area is not global, "Explore" is
      });

      expect(mockFlowQueryHandler).toHaveBeenCalledWith({
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
      createComponent({ flowQueryHandler: jest.fn().mockRejectedValue(error) });
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
      expect(findErrorAlert().props('errors')).toEqual(['Flow does not exist']);
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('when displaying different flow versions', () => {
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
        provide: { projectId: 1, rootGroupId: '1' },
      });
      await waitForPromises();

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
      });
    });
  });

  describe('when itemType is not FLOW or THIRD_PARTY_FLOW', () => {
    it('renders flow not found', async () => {
      const mockAgentResponse = {
        data: {
          aiCatalogItem: {
            ...mockFlow,
            itemType: 'AGENT',
          },
        },
      };
      createComponent({
        flowQueryHandler: jest.fn().mockResolvedValue(mockAgentResponse),
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
            ...mockFlow,
            configurationForProject: {
              ...mockFlowConfigurationForProject,
              ...configurationForProject,
              userPermissions: {
                ...(configurationForProject.userPermissions ??
                  mockFlowConfigurationForProject.userPermissions),
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
          flowQueryHandler: mockHandler,
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
      beforeEach(() => {});

      it('should show update alert when a new version is available and user has permissions', async () => {
        const mockHandler = mockHandlerFactory({
          permission: { adminAiCatalogItemConsumer: true },
        });
        createComponent({
          flowQueryHandler: mockHandler,
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
          flowQueryHandler: mockHandler,
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
              ...mockFlowPinnedVersion,
              id: 'asd',
              humanVersionName: mockFlowVersion.humanVersionName, // Same as latest
            },
          },
          permission: { adminAiCatalogItemConsumer: true },
        });
        createComponent({
          flowQueryHandler: mockHandler,
          provide: { projectId: 1 },
        });
        await waitForPromises();
        const routerView = findRouterView();
        expect(routerView.props('version').isUpdateAvailable).toBe(false);
        expect(routerView.props('version').activeVersionKey).toBe(VERSION_PINNED);
      });
    });
  });
});
