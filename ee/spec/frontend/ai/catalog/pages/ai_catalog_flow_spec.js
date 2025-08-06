import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogFlow from 'ee/ai/catalog/pages/ai_catalog_flow.vue';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import { mockAiCatalogFlowResponse, mockAiCatalogFlowNullResponse, mockFlow } from '../mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

const RouterViewStub = Vue.extend({
  name: 'RouterViewStub',
  // eslint-disable-next-line vue/require-prop-types
  props: ['aiCatalogFlow'],
  template: '<div />',
});

describe('AiCatalogFlow', () => {
  let wrapper;
  let mockApollo;
  const flowId = 1;
  const routeParams = { id: flowId };

  const mockFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);
  const mockFlowNullQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowNullResponse);

  const createComponent = ({ flowQueryHandler = mockFlowQueryHandler } = {}) => {
    mockApollo = createMockApollo([[aiCatalogFlowQuery, flowQueryHandler]]);

    wrapper = shallowMount(AiCatalogFlow, {
      apolloProvider: mockApollo,
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

    it('creates an alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: error.message,
        captureError: true,
        error,
      });
    });
  });
});
