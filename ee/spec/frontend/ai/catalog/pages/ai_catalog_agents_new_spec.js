import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import createAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogThirdPartyFlowSuccessMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsNew', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let createAiCatalogThirdPartyFlowMock;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = () => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    createAiCatalogThirdPartyFlowMock = jest
      .fn()
      .mockResolvedValue(mockCreateAiCatalogThirdPartyFlowSuccessMutation);
    const apolloProvider = createMockApollo([
      [createAiCatalogAgent, createAiCatalogAgentMock],
      [createAiCatalogThirdPartyFlow, createAiCatalogThirdPartyFlowMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentsNew, {
      apolloProvider,
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogAgentForm);

  beforeEach(() => {
    createComponent();
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockAgent;
    const input = {
      name,
      description,
      projectId: project.id,
      systemPrompt: 'A new system prompt',
      userPrompt: 'A new user prompt',
      public: false,
    };

    const submitForm = () => findForm().vm.$emit('submit', { itemType: 'AGENT', ...input });

    it('sends a create request', () => {
      submitForm();

      expect(createAiCatalogAgentMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogAgentMock).toHaveBeenCalledWith({
        input,
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();

      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        createAiCatalogAgentMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual([
          'Could not create agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
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
        createAiCatalogAgentMock.mockResolvedValue(mockCreateAiCatalogAgentErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
          mockCreateAiCatalogAgentErrorMutation.data.aiCatalogAgentCreate.errors[0],
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
        expect(mockToast.show).toHaveBeenCalledWith('Agent created.');
      });

      it('navigates to agents show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_SHOW_ROUTE,
          params: { id: 1 },
        });
      });
    });

    describe('when item type is third-party flow', () => {
      const inputThirdPartyFlow = {
        name,
        description,
        projectId: project.id,
        public: true,
        definition: 'image:node@22',
      };

      const submitThirdPartyFlowForm = () =>
        findForm().vm.$emit('submit', { itemType: 'THIRD_PARTY_FLOW', ...inputThirdPartyFlow });

      it('sends a create request for third-party flow', () => {
        submitThirdPartyFlowForm();

        expect(createAiCatalogAgentMock).not.toHaveBeenCalled();
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledTimes(1);
        expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledWith({
          input: inputThirdPartyFlow,
        });
      });
    });
  });
});
