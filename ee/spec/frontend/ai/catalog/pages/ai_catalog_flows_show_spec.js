import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogFlowsShow from 'ee/ai/catalog/pages/ai_catalog_flows_show.vue';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import { TRACK_EVENT_TYPE_FLOW, TRACK_EVENT_VIEW_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import deleteAiCatalogThirdPartyFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_third_party_flow.mutation.graphql';
import {
  mockCatalogFlowDeleteErrorResponse,
  mockCatalogFlowDeleteResponse,
  mockFlow,
  mockThirdPartyFlow,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogFlowsShow', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    aiCatalogFlow: mockFlow,
  };

  const deleteFlowMutationHandler = jest.fn().mockResolvedValue(mockCatalogFlowDeleteResponse);
  const deleteThirdPartyFlowMutationHandler = jest.fn();
  const routeParams = { id: '1' };
  const mockToast = {
    show: jest.fn(),
  };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([
      [deleteAiCatalogFlowMutation, deleteFlowMutationHandler],
      [deleteAiCatalogThirdPartyFlowMutation, deleteThirdPartyFlowMutationHandler],
    ]);

    wrapper = shallowMount(AiCatalogFlowsShow, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        isGlobal: false,
        glFeatures: {
          aiCatalogItemProjectCuration: true,
        },
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
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
  const findFlowDetails = () => wrapper.findComponent(AiCatalogFlowDetails);

  beforeEach(() => {
    createComponent();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(mockFlow.name);
  });

  it('renders item actions', () => {
    expect(findItemActions().props('item')).toBe(mockFlow);
  });

  it('renders flow details', () => {
    expect(findFlowDetails().props('item')).toBe(mockFlow);
  });

  describe('tracking events', () => {
    it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
        { label: TRACK_EVENT_TYPE_FLOW },
        undefined,
      );
    });
  });

  describe('on deleting a flow', () => {
    const deleteFlow = () => findItemActions().props('deleteFn')();

    it('calls delete mutation for flow', () => {
      deleteFlow();

      expect(deleteThirdPartyFlowMutationHandler).not.toHaveBeenCalled();
      expect(deleteFlowMutationHandler).toHaveBeenCalledWith({ id: mockFlow.id });
    });

    describe('when flow type is third-party flow', () => {
      beforeEach(() => {
        createComponent({
          props: {
            aiCatalogFlow: mockThirdPartyFlow,
          },
        });
      });

      it('calls delete mutation for third-party flow', () => {
        deleteFlow();

        expect(deleteFlowMutationHandler).not.toHaveBeenCalled();
        expect(deleteThirdPartyFlowMutationHandler).toHaveBeenCalledWith({
          id: mockThirdPartyFlow.id,
        });
      });
    });

    describe('when request succeeds', () => {
      it('shows a toast message', async () => {
        deleteFlow();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Flow deleted.');
      });
    });

    describe('when request succeeds but returns errors', () => {
      it('shows alert with error', async () => {
        deleteFlowMutationHandler.mockResolvedValue(mockCatalogFlowDeleteErrorResponse);

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. You do not have permission to delete this AI flow.',
        ]);
      });
    });

    describe('when request fails', () => {
      it('shows alert with error and captures exception', async () => {
        deleteFlowMutationHandler.mockRejectedValue(new Error('Request failed'));

        deleteFlow();

        await waitForPromises();
        expect(findErrorsAlert().props('errors')).toEqual([
          'Failed to delete flow. Error: Request failed',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});
