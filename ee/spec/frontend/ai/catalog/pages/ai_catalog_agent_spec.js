import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogAgent from 'ee/ai/catalog/pages/ai_catalog_agent.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import {
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentNullResponse,
  mockAgent,
  mockAgentConfigurationForProject,
  mockAgentConfigurationForGroup,
  mockAgentVersion,
  mockAgentPinnedVersion,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = Vue.extend({
  name: 'RouterViewStub',
  // eslint-disable-next-line vue/require-prop-types
  props: ['aiCatalogAgent', 'versionData'],
  template: '<div />',
});

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
        'router-view': RouterViewStub,
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
        configurationForGroup: mockAgentConfigurationForGroup,
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
      expect(routerView.props('versionData')).toMatchObject({
        systemPrompt: mockAgentVersion.systemPrompt, // uses mock latest version data
        tools: mockAgentVersion.tools.nodes,
      });
    });

    it('should show pinned version when in project area', async () => {
      createComponent({
        provide: { projectId: 1 },
      });
      await waitForPromises();

      const routerView = findRouterView();
      expect(routerView.props('versionData')).toMatchObject({
        systemPrompt: mockAgentPinnedVersion.systemPrompt, // uses mock pinned version data
        tools: mockAgentPinnedVersion.tools.nodes,
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
});
