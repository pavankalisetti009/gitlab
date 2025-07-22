import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsNew from 'ee/ai/catalog/pages/ai_catalog_flows_new.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import {
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';
import {
  mockBaseFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsNew', () => {
  let wrapper;
  let createAiCatalogFlowMock;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = () => {
    createAiCatalogFlowMock = jest.fn().mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
    const apolloProvider = createMockApollo([[createAiCatalogFlow, createAiCatalogFlowMock]]);

    wrapper = shallowMountExtended(AiCatalogFlowsNew, {
      apolloProvider,
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogFlowForm);

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockBaseFlow;
    const formValues = {
      name,
      description,
      projectId: project.id,
      public: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends a create request', () => {
      submitForm();

      expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogFlowMock).toHaveBeenCalledWith({
        input: formValues,
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errorMessages')).toEqual([
          'The flow could not be added. Please try again.',
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
        createAiCatalogFlowMock.mockResolvedValue(mockCreateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errorMessages')).toEqual([
          mockCreateAiCatalogFlowErrorMutation.data.aiCatalogFlowCreate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow created successfully.');
      });

      it('navigates to flows page with show query', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_ROUTE,
          query: { [AI_CATALOG_SHOW_QUERY_PARAM]: 4 },
        });
      });
    });
  });
});
