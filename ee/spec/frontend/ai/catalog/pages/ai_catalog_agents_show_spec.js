import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import { TRACK_EVENT_TYPE_AGENT, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAgent,
  mockConfigurationForProject,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogAgentsShow', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };

  const defaultProps = {
    aiCatalogAgent: { ...mockAgent, configurationForProject: mockConfigurationForProject },
  };

  const routeParams = { id: '1' };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);
    wrapper = shallowMount(AiCatalogAgentsShow, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
      },
      provide: {
        isGlobal: false,
        projectId: '1',
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $toast: mockToast,
      },
    });
  };

  const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
  const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
  const findItemView = () => wrapper.findComponent(AiCatalogItemView);

  beforeEach(() => {
    createComponent();
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toEqual({
      ...mockAgent,
      configurationForProject: mockConfigurationForProject,
    });
  });

  it('renders item view', () => {
    expect(findItemView().props('item')).toEqual({
      ...mockAgent,
      configurationForProject: mockConfigurationForProject,
    });
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_AGENT },
        undefined,
      );
    });
  });

  describe('on disabling an agent', () => {
    const disableAgent = () => findItemActions().props('disableFn')();

    it('calls disable mutation for agent', () => {
      disableAgent();

      expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
        id: mockConfigurationForProject.id,
      });
    });

    describe('when request succeeds', () => {
      it('shows toast', async () => {
        disableAgent();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agent disabled in this project.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows error alert', async () => {
        deleteItemConsumerMutationHandler.mockResolvedValue(
          mockAiCatalogItemConsumerDeleteErrorResponse,
        );
        disableAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable agent. You do not have permission to disable this item.',
        ]);
      });
    });

    describe('when request failes', () => {
      it('shows error alert and captures exception', async () => {
        deleteItemConsumerMutationHandler.mockRejectedValue(new Error('custom error'));
        disableAgent();
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to disable agent. Error: custom error',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});
