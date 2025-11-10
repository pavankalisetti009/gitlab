import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogFlowsEdit from 'ee/ai/catalog/pages/ai_catalog_flows_edit.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import updateAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import updateAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';
import { AI_CATALOG_FLOWS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockFlow,
  mockUpdateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowErrorMutation,
  mockThirdPartyFlow,
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
  const mockUpdateAiCatalogThirdPartyFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);

  const createComponent = ({ props = {} } = {}) => {
    mockApollo = createMockApollo([
      [updateAiCatalogFlow, mockUpdateAiCatalogFlowHandler],
      [updateAiCatalogThirdPartyFlow, mockUpdateAiCatalogThirdPartyFlowHandler],
    ]);

    wrapper = shallowMount(AiCatalogFlowsEdit, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
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
    const { name, description, latestVersion } = mockFlow;
    const formValues = {
      name,
      description,
      public: true,
      definition: latestVersion.definition,
      itemType: 'FLOW',
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends an update request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      const { itemType, ...input } = formValues;

      expect(mockUpdateAiCatalogThirdPartyFlowHandler).not.toHaveBeenCalled();
      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogFlowHandler).toHaveBeenCalledWith({
        input: { ...input, id: mockFlow.id },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await findForm().vm.$emit('submit', {});
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when flow type is third-party flow', () => {
      beforeEach(() => {
        createComponent({
          props: {
            aiCatalogFlow: mockThirdPartyFlow,
          },
        });
      });
      const thirdPartyFlowFormValues = {
        name,
        description,
        public: true,
        definition: 'image:node@22',
        itemType: 'THIRD_PARTY_FLOW',
      };

      const submitThirdPartyForm = () => findForm().vm.$emit('submit', thirdPartyFlowFormValues);

      it('sends a create request for third-party flow', () => {
        submitThirdPartyForm();

        const { itemType, ...input } = thirdPartyFlowFormValues;

        expect(mockUpdateAiCatalogFlowHandler).not.toHaveBeenCalled();
        expect(mockUpdateAiCatalogThirdPartyFlowHandler).toHaveBeenCalledTimes(1);
        expect(mockUpdateAiCatalogThirdPartyFlowHandler).toHaveBeenCalledWith({
          input: { ...input, id: mockThirdPartyFlow.id },
        });
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Flow updated.');
      });

      it('navigates to flows show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_FLOWS_SHOW_ROUTE,
          params: { id: flowId },
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
        expect(findForm().props('errors')).toEqual(['Could not update flow. Try again.']);
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
        mockUpdateAiCatalogFlowHandler.mockResolvedValue(mockUpdateAiCatalogFlowErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
          mockUpdateAiCatalogFlowErrorMutation.data.aiCatalogFlowUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });
});
