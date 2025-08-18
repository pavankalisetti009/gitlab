import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsNew', () => {
  let wrapper;
  let createAiCatalogAgentMock;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = () => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    const apolloProvider = createMockApollo([[createAiCatalogAgent, createAiCatalogAgentMock]]);

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

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockAgent;
    const formValues = {
      name,
      description,
      projectId: project.id,
      systemPrompt: 'A new system prompt',
      userPrompt: 'A new user prompt',
      public: false,
      release: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends a create request', () => {
      submitForm();

      expect(createAiCatalogAgentMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogAgentMock).toHaveBeenCalledWith({
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
        createAiCatalogAgentMock.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errorMessages')).toEqual([
          'The agent could not be added. Try again.',
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
        createAiCatalogAgentMock.mockResolvedValue(mockCreateAiCatalogAgentErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errorMessages')).toEqual([
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
        expect(mockToast.show).toHaveBeenCalledWith('Agent created successfully.');
      });

      it('navigates to agents page with show query', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_ROUTE,
          query: { [AI_CATALOG_SHOW_QUERY_PARAM]: 1 },
        });
      });
    });
  });
});
