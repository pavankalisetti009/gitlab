import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogAgentSuccessWithEnableFailureMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');
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

  const createComponent = ({ aiCatalogFlows = false } = {}) => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    const apolloProvider = createMockApollo([[createAiCatalogAgent, createAiCatalogAgentMock]]);

    wrapper = shallowMountExtended(AiCatalogAgentsNew, {
      apolloProvider,
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
      provide: {
        glFeatures: {
          aiCatalogFlows,
        },
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogAgentForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    createComponent();
  });

  describe('Rendering', () => {
    it('renders the correct description text when aiCatalogFlows feature flag is enabled', () => {
      createComponent({ aiCatalogFlows: true });

      expect(findPageHeading().text()).toContain(
        'Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
      );
    });

    it('renders the correct description text when aiCatalogFlows feature flag is disabled', () => {
      createComponent({ aiCatalogFlows: false });

      expect(findPageHeading().text()).toContain(
        'Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
      );
    });
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

    describe('when request succeeds but fails to enable the agent', () => {
      beforeEach(async () => {
        createAiCatalogAgentMock.mockResolvedValue(
          mockCreateAiCatalogAgentSuccessWithEnableFailureMutation,
        );
        submitForm();
        await waitForPromises();
      });

      it('calls createAlert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message:
            'Could not enable agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
          messageLinks: {
            link: '/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog',
          },
        });
      });

      it('navigates to agents show page', async () => {
        await waitForPromises();
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_SHOW_ROUTE,
          params: { id: 1 },
        });
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
  });
});
