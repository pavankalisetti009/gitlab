import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogFlowsEdit from 'ee/ai/catalog/pages/ai_catalog_flows_edit.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import updateAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import {
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockUpdateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsEdit', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    aiCatalogFlow: mockFlow,
  };
  const flowId = 4;
  const routeParams = { id: flowId };
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const mockUpdateAiCatalogFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);

  const createComponent = () => {
    mockApollo = createMockApollo([[updateAiCatalogFlow, mockUpdateAiCatalogFlowHandler]]);

    wrapper = shallowMount(AiCatalogFlowsEdit, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogFlowForm);

  beforeEach(() => {
    createComponent();
  });

  it('render edit form', () => {
    expect(findForm().exists()).toBe(true);
  });

  describe('Form Submit', () => {
    const { name, description } = mockFlow;
    const formValues = {
      name,
      description,
      // TODO: Add Public/private radio buttons to form submit
      public: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends an update request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledWith({
        input: { ...formValues, id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, flowId) },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await findForm().vm.$emit('submit', {});
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow updated successfully.');
      });

      it('navigates to flows page with show query', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_ROUTE,
          query: { [AI_CATALOG_SHOW_QUERY_PARAM]: flowId },
        });
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogFlowHandler.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errorMessages')).toEqual([
          'The flow could not be updated. Please try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-error');

        expect(findForm().props('errorMessages')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogFlowHandler.mockResolvedValue(mockUpdateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errorMessages')).toEqual([
          mockUpdateAiCatalogFlowErrorMutation.data.aiCatalogFlowUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });
});
