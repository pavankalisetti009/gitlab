import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsDuplicate from 'ee/ai/catalog/pages/ai_catalog_flows_duplicate.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import { mapSteps } from 'ee/ai/catalog/utils';
import {
  mockFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsDuplicate', () => {
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

    wrapper = shallowMountExtended(AiCatalogFlowsDuplicate, {
      apolloProvider,
      propsData: {
        aiCatalogFlow: mockFlow,
      },
      mocks: {
        $route: {
          params: { id: 1 },
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

  describe('Form Initial Values', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('sets initial values based on the original agent, but always private and without a project', () => {
      const expectedInitialValues = {
        type: 'FLOW',
        name: `Copy of ${mockFlow.name}`,
        description: mockFlow.description,
        steps: mapSteps(mockFlow.latestVersion.steps),
        public: false,
      };

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockFlow;
    const formValues = {
      name: `${name} 2`,
      description,
      projectId: project.id,
      steps: mapSteps(mockFlow.latestVersion.steps),
      public: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(async () => {
      await waitForPromises();
    });

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

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errors')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockResolvedValue(mockCreateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
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

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: 4 },
        });
      });
    });
  });
});
