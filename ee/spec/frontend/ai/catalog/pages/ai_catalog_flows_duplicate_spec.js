import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import AiCatalogFlowsDuplicate from 'ee/ai/catalog/pages/ai_catalog_flows_duplicate.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import createAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import {
  mockFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsDuplicate', () => {
  let wrapper;

  const createAiCatalogFlowMock = jest
    .fn()
    .mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
  const createAiCatalogThirdPartyFlowMock = jest
    .fn()
    .mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({ provide = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [createAiCatalogFlow, createAiCatalogFlowMock],
      [createAiCatalogThirdPartyFlow, createAiCatalogThirdPartyFlowMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogFlowsDuplicate, {
      apolloProvider,
      propsData: {
        aiCatalogFlow: mockFlow,
      },
      provide: {
        ...provide,
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
        definition: mockFlow.latestVersion.definition,
        public: false,
        release: true,
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
      definition: mockFlow.definition,
      public: true,
      itemType: 'FLOW',
      release: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(async () => {
      await waitForPromises();
    });

    it('sends a create request', () => {
      submitForm();

      const { itemType, ...input } = formValues;

      expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogFlowMock).toHaveBeenCalledWith({
        input,
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when flow type is third-party flow', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              aiCatalogThirdPartyFlows: true,
            },
          },
        });
      });

      const thirdPartyFlowFormValues = {
        name,
        description,
        projectId: project.id,
        public: true,
        itemType: 'THIRD_PARTY_FLOW',
        definition: 'image:node@22',
      };

      const submitThirdPartyForm = () => findForm().vm.$emit('submit', thirdPartyFlowFormValues);

      it('sends a create request for third-party flow', () => {
        submitThirdPartyForm();

        const { itemType, ...input } = thirdPartyFlowFormValues;

        expect(createAiCatalogFlowMock).not.toHaveBeenCalled();
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledTimes(1);
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledWith({
          input,
        });
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow created.');
      });

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: 4 },
        });
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual([
          'Could not create flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
        ]);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
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
  });
});
