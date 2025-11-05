import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import AiCatalogFlowsNew from 'ee/ai/catalog/pages/ai_catalog_flows_new.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowSuccessWithEnableFailureMutation,
  mockCreateAiCatalogFlowErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogFlowsNew', () => {
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

    wrapper = shallowMountExtended(AiCatalogFlowsNew, {
      apolloProvider,
      provide: {
        ...provide,
      },
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
    const { name, description, project, latestVersion } = mockFlow;
    const formValues = {
      name,
      description,
      projectId: project.id,
      public: true,
      release: true,
      definition: latestVersion.definition,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues, 'FLOW');

    it('sends a create request', () => {
      submitForm();

      expect(createAiCatalogThirdPartyFlowMock).not.toHaveBeenCalled();
      expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogFlowMock).toHaveBeenCalledWith({
        input: { ...formValues, addToProjectWhenCreated: true },
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
        definition: 'image:node@22',
      };

      const submitThirdPartyForm = () =>
        findForm().vm.$emit('submit', thirdPartyFlowFormValues, 'THIRD_PARTY_FLOW');

      it('sends a create request for third-party flow', () => {
        submitThirdPartyForm();

        expect(createAiCatalogFlowMock).not.toHaveBeenCalled();
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledTimes(1);
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledWith({
          input: { ...thirdPartyFlowFormValues, addToProjectWhenCreated: true },
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

    describe('when request succeeds but fails to enable the flow', () => {
      beforeEach(async () => {
        createAiCatalogFlowMock.mockResolvedValue(
          mockCreateAiCatalogFlowSuccessWithEnableFailureMutation,
        );
        submitForm();
        await waitForPromises();
      });

      it('calls createAlert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message:
            'Could not enable flow in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
          messageLinks: {
            link: '/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog',
          },
        });
      });

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: 4 },
        });
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
