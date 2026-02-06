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
import * as utils from 'ee/ai/catalog/utils';
import {
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentNullResponse,
  mockAgent,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockAgentVersion,
  mockAgentPinnedVersion,
  mockAgentGroupPinnedVersion,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = {
  name: 'RouterViewStub',
  props: ['aiCatalogAgent', 'version', 'hasParentConsumer'],
  template: '<div />',
};

const aiCatalogAgentWithBothConfigs = {
  ...mockAgent,
  configurationForGroup: mockItemConfigurationForGroup,
  configurationForProject: mockAgentConfigurationForProject,
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

  describe('loading', () => {
    beforeEach(() => {
      createComponent({
        // we include rootGroupId so that internal logic doesn't result in the mockApollo stripping the config for group
        provide: { projectId: '1', rootGroupId: '1' },
      });
    });

    it('renders loading icon while fetching data', async () => {
      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findGlLoadingIcon().exists()).toBe(false);
    });
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
        provide: { projectId: '1', rootGroupId: '1' },
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
    let resolveVersionSpy;

    const mockItemBothConfigsHandler = jest.fn().mockResolvedValue({
      data: {
        aiCatalogItem: aiCatalogAgentWithBothConfigs,
      },
    });

    beforeEach(() => {
      resolveVersionSpy = jest
        .spyOn(utils, 'resolveVersion')
        .mockReturnValue({ ...mockAgentVersion, key: VERSION_LATEST });
    });

    afterEach(() => {
      resolveVersionSpy.mockRestore();
    });

    it('should show latest version when in the explore area', async () => {
      createComponent({
        provide: { isGlobal: true },
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(mockAgent, true);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: false,
        activeVersionKey: VERSION_LATEST,
      });
    });

    it('should show group pinned version when in the group area', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockAgentGroupPinnedVersion,
        key: VERSION_PINNED_GROUP,
      });

      createComponent({
        provide: { groupId: '1', projectId: null },
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(
        {
          ...mockAgent,
          configurationForGroup: mockItemConfigurationForGroup,
        },
        false,
      );

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED_GROUP,
      });
    });

    it('should show project pinned version when in project area', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockAgentPinnedVersion,
        key: VERSION_PINNED,
      });

      createComponent({
        provide: { projectId: '1', rootGroupId: '1' },
        agentQueryHandler: mockItemBothConfigsHandler,
      });
      await waitForPromises();

      expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogAgentWithBothConfigs, false);

      const routerView = findRouterView();
      expect(routerView.props('version')).toMatchObject({
        isUpdateAvailable: true,
        activeVersionKey: VERSION_PINNED,
      });
    });

    it('should show group pinned version when in the project area without a project configuration', async () => {
      resolveVersionSpy.mockReturnValue({
        ...mockAgentGroupPinnedVersion,
        key: VERSION_PINNED_GROUP,
      });

      const aiCatalogItem = {
        ...mockAgent,
        configurationForProject: null,
        configurationForGroup: mockItemConfigurationForGroup,
      };

      const mockItemWithGroupConfigOnlyHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem,
        },
      });

      createComponent({
        provide: { groupId: '1', projectId: '1', rootGroupId: '1' },
        agentQueryHandler: mockItemWithGroupConfigOnlyHandler,
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
        ...mockAgentVersion,
        key: VERSION_LATEST,
      });

      const aiCatalogItem = {
        ...mockAgent,
        configurationForProject: null,
      };

      const mockItemWithNoConfigHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem,
        },
      });

      createComponent({
        provide: { groupId: '1', projectId: '1' },
        agentQueryHandler: mockItemWithNoConfigHandler,
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

  describe('adds the correct page title', () => {
    it('prefixes the agent name to the base page title', async () => {
      document.title = 'Agents · Automate · GitLab';

      const mockAgentWithNameHandler = jest.fn().mockResolvedValue({
        data: {
          aiCatalogItem: {
            ...mockAgent,
            name: 'My Agent',
            configurationForProject: mockAgentConfigurationForProject,
            configurationForGroup: mockItemConfigurationForGroup,
          },
        },
      });

      createComponent({
        agentQueryHandler: mockAgentWithNameHandler,
      });
      await waitForPromises();

      expect(document.title).toBe('My Agent · Agents · Automate · GitLab');
    });
  });
});
