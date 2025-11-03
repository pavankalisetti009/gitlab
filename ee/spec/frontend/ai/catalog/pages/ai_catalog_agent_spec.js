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
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = Vue.extend({
  name: 'RouterViewStub',
  // eslint-disable-next-line vue/require-prop-types
  props: ['aiCatalogAgent'],
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
    createComponent();
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
      await waitForPromises();
    });

    it('does not render empty state', () => {
      expect(findGlEmptyState().exists()).toBe(false);
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
      expect(findRouterView().props('aiCatalogAgent')).toEqual(mockAgent);
    });
  });

  describe('when displaying soft-deleted agents', () => {
    it('should show agent details in the Projects area', async () => {
      createComponent();
      await waitForPromises();

      expect(mockAgentQueryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::Item/1',
        showSoftDeleted: true,
      });
    });

    it('should not show agent details in the explore area', async () => {
      createComponent({
        provide: { isGlobal: true }, // "Projects" area is not global, "Explore" is
      });
      await waitForPromises();

      expect(mockAgentQueryHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::Item/1',
        showSoftDeleted: false,
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
});
