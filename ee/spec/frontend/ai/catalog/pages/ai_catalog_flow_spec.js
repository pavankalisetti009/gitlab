import Vue, { nextTick } from 'vue';
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
import * as utils from 'ee/ai/catalog/utils';
import {
  mockAiCatalogFlowResponse,
  mockAiCatalogFlowNullResponse,
  mockFlow,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockFlowVersion,
  mockFlowPinnedVersion,
  mockFlowGroupPinnedVersion,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = {
  name: 'RouterViewStub',
  props: ['aiCatalogFlow', 'version', 'hasParentConsumer'],
  template: '<div />',
};

const aiCatalogFlowWithBothConfigs = {
  ...mockFlow,
  configurationForGroup: mockFlowConfigurationForGroup,
  configurationForProject: mockFlowConfigurationForProject,
};

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
        RouterView: RouterViewStub,
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
    let resolveVersionSpy;

    beforeEach(() => {
      resolveVersionSpy = jest
        .spyOn(utils, 'resolveVersion')
        .mockReturnValue({ ...mockFlowVersion, key: VERSION_LATEST });
    });

    afterEach(() => {
      resolveVersionSpy.mockRestore();
    });

    it('should show latest version when in the explore area', async () => {
      createComponent({
        provide: { isGlobal: true },
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(mockFlow, true);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
      });
    });

    it('should show group pinned version when in the group area', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockFlowGroupPinnedVersion,
        key: VERSION_PINNED_GROUP,
      });

      const aiCatalogFlow = {
        ...mockFlow,
        configurationForGroup: mockFlowConfigurationForGroup,
      };

      createComponent({
        provide: { groupId: '1', projectId: null },
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogFlow, false);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
      });
    });

    it('should show project pinned version when in project area', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockFlowPinnedVersion,
        key: VERSION_PINNED,
      });

      const mockFlowBothConfigsHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem: aiCatalogFlowWithBothConfigs,
        },
      });

      createComponent({
        provide: { projectId: '1', rootGroupId: '1' },
        flowQueryHandler: mockFlowBothConfigsHandler,
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogFlowWithBothConfigs, false);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
      });
    });

    it('should show group pinned version when in the project area without a project configuration', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockFlowGroupPinnedVersion,
        key: VERSION_PINNED_GROUP,
      });

      const aiCatalogItem = {
        ...mockFlow,
        configurationForProject: null,
        configurationForGroup: mockFlowConfigurationForGroup,
      };

      const mockFlowWithGroupConfigOnlyHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem,
        },
      });

      createComponent({
        provide: { groupId: '1', projectId: '1', rootGroupId: '1' },
        flowQueryHandler: mockFlowWithGroupConfigOnlyHandler,
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogItem, false);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
      });
    });

    it('should show latest version when in the project area without a group nor project configuration', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockFlowVersion,
        key: VERSION_LATEST,
      });

      const aiCatalogItem = {
        ...mockFlow,
        configurationForProject: null,
      };

      const mockFlowWithNoConfigHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem,
        },
      });

      createComponent({
        provide: { groupId: '1', projectId: '1' },
        flowQueryHandler: mockFlowWithNoConfigHandler,
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogItem, false);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
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

  describe.each`
    hasParentConsumer | configurationForGroupEnabled
    ${true}           | ${true}
    ${false}          | ${false}
  `(
    'when configurationForGroup.enabled is $configurationForGroupEnabled',
    ({ hasParentConsumer, configurationForGroupEnabled }) => {
      beforeEach(async () => {
        const mockFlowGroupConfigQueryHandler = jest.fn().mockResolvedValue({
          data: {
            aiCatalogItem: {
              ...mockFlow,
              configurationForProject: mockFlowConfigurationForProject,
              configurationForGroup: {
                ...mockFlowConfigurationForGroup,
                enabled: configurationForGroupEnabled,
              },
            },
          },
        });
        createComponent({
          provide: { projectId: 1, rootGroupId: '1' },
          flowQueryHandler: mockFlowGroupConfigQueryHandler,
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

  describe('adds the correct page title', () => {
    it('prefixes the flow name to the base page title', async () => {
      document.title = 'Flows · Automate · GitLab';

      const mockFlowWithNameHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem: {
            ...mockFlow,
            name: 'My Flow',
            configurationForProject: mockFlowConfigurationForProject,
            configurationForGroup: mockFlowConfigurationForGroup,
          },
        },
      });

      createComponent({
        provide: { projectId: '1', rootGroupId: '1' },
        flowQueryHandler: mockFlowWithNameHandler,
      });
      await waitForPromises();

      expect(document.title).toBe('My Flow · Flows · Automate · GitLab');
    });
  });
});
