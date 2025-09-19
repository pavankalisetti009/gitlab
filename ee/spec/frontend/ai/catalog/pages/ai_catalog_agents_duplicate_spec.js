import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import AiCatalogAgentsDuplicate from 'ee/ai/catalog/pages/ai_catalog_agents_duplicate.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentNullResponse,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsDuplicate', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let aiCatalogAgentQueryMock;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };
  const agentId = 1;
  const routeParams = { id: agentId };

  const createComponent = () => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    aiCatalogAgentQueryMock = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);

    const apolloProvider = createMockApollo([
      [createAiCatalogAgent, createAiCatalogAgentMock],
      [aiCatalogAgentQuery, aiCatalogAgentQueryMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentsDuplicate, {
      apolloProvider,
      mocks: {
        $route: {
          params: routeParams,
        },
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

  describe('Initial Load', () => {
    it('fetches the original agent data', () => {
      expect(aiCatalogAgentQueryMock).toHaveBeenCalledWith({
        id: mockAgent.id,
      });
    });

    it('renders the form with loading state initially', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('isLoading')).toBe(true);
    });
  });

  describe('Form Initial Values', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('sets initial values based on the original agent', () => {
      const expectedInitialValues = {
        name: `Copy of ${mockAgent.name}`,
        description: mockAgent.description,
        systemPrompt: mockAgent.latestVersion.systemPrompt,
        userPrompt: mockAgent.latestVersion.userPrompt,
        tools: mockAgent.latestVersion.tools.nodes.map((t) => t.id),
      };

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockAgent;
    const formValues = {
      name: `${name} (Copy)`,
      description,
      projectId: project.id,
      systemPrompt: 'A new system prompt',
      userPrompt: 'A new user prompt',
      public: false,
      release: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(async () => {
      await waitForPromises();
    });

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
        expect(findForm().props('errors')).toEqual([
          'The agent could not be added to the project. Check that the project meets the <a href="/help/user/ai_catalog#prerequisites" target="_blank">prerequisites</a> and try again.',
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

  describe('Error Handling', () => {
    describe('when agent query fails', () => {
      it('captures the exception', async () => {
        const error = new Error('Agent not found.');

        const apolloProvider = createMockApollo([
          [createAiCatalogAgent, createAiCatalogAgentMock],
          [aiCatalogAgentQuery, jest.fn().mockRejectedValue(error)],
        ]);

        wrapper = shallowMountExtended(AiCatalogAgentsDuplicate, {
          apolloProvider,
          mocks: {
            $route: {
              params: routeParams,
            },
            $router: mockRouter,
            $toast: mockToast,
          },
        });

        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });

    describe('when agent query returns null', () => {
      it('handles null response gracefully', async () => {
        const apolloProvider = createMockApollo([
          [createAiCatalogAgent, createAiCatalogAgentMock],
          [aiCatalogAgentQuery, jest.fn().mockResolvedValue(mockAiCatalogAgentNullResponse)],
        ]);

        wrapper = shallowMountExtended(AiCatalogAgentsDuplicate, {
          apolloProvider,
          mocks: {
            $route: {
              params: routeParams,
            },
            $router: mockRouter,
            $toast: mockToast,
          },
        });

        await waitForPromises();

        expect(findForm().props('initialValues')).toEqual({});
      });
    });
  });
});
