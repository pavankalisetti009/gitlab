import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import createAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import AiCatalogAgentsDuplicate from 'ee/ai/catalog/pages/ai_catalog_agents_duplicate.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogThirdPartyFlowSuccessMutation,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsDuplicate', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let createAiCatalogThirdPartyFlowMock;

  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const agentId = 1;
  const routeParams = { id: agentId };
  const defaultProps = {
    aiCatalogAgent: mockAgent,
  };

  const createComponent = (props = {}, provide = {}) => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    createAiCatalogThirdPartyFlowMock = jest
      .fn()
      .mockResolvedValue(mockCreateAiCatalogThirdPartyFlowSuccessMutation);

    const apolloProvider = createMockApollo([
      [createAiCatalogAgent, createAiCatalogAgentMock],
      [createAiCatalogThirdPartyFlow, createAiCatalogThirdPartyFlowMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentsDuplicate, {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
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

  const findForm = () => wrapper.findComponent(AiCatalogAgentForm);
  const findFormInitialValues = () => findForm().props('initialValues');

  beforeEach(() => {
    createComponent();
  });

  describe('Form Initial Values', () => {
    const baseExpectedInitialValues = {
      name: `Copy of ${mockAgent.name}`,
      description: mockAgent.description,
      type: 'AGENT',
      public: false,
    };

    const expectedInitialValuesWithProjectPinnedVersion = {
      ...baseExpectedInitialValues,
      systemPrompt: mockAgentConfigurationForProject.pinnedItemVersion.systemPrompt,
      tools: mockAgentConfigurationForProject.pinnedItemVersion.tools.nodes.map((t) => t.id),
    };

    const expectedInitialValuesWithGroupPinnedVersion = {
      ...baseExpectedInitialValues,
      systemPrompt: mockItemConfigurationForGroup.pinnedItemVersion.systemPrompt,
      tools: mockItemConfigurationForGroup.pinnedItemVersion.tools.nodes.map((t) => t.id),
    };

    const expectedInitialValuesWithLatestVersion = {
      ...baseExpectedInitialValues,
      systemPrompt: mockAgent.latestVersion.systemPrompt,
      tools: mockAgent.latestVersion.tools.nodes.map((t) => t.id),
    };

    it('sets initial item public field and removes project field correctly', async () => {
      createComponent(
        {
          aiCatalogAgent: {
            ...mockAgent,
            configurationForProject: {
              ...mockAgentConfigurationForProject,
              public: true,
            },
          },
        },
        {
          isGlobal: false,
          projectId: '1',
        },
      );
      await waitForPromises();

      const formProps = findFormInitialValues();

      expect(formProps).not.toHaveProperty('project');
      expect(formProps).toEqual({
        ...expectedInitialValuesWithProjectPinnedVersion,
        public: false,
      });
    });

    describe('being set correctly in global context', () => {
      it('sets initial values to latest version', async () => {
        createComponent(
          {
            aiCatalogAgent: {
              ...mockAgent,
              configurationForProject: mockAgentConfigurationForProject, // not expected
            },
          },
          {
            isGlobal: true,
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);
      });
    });

    describe('being set correctly in project context', () => {
      it('sets initial values to latest version when no configurations are present', async () => {
        createComponent(
          {
            aiCatalogAgent: mockAgent,
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);
      });

      it('sets initial values to group-pinned version when only group configuration is present', async () => {
        createComponent(
          {
            aiCatalogAgent: { ...mockAgent, configurationForGroup: mockItemConfigurationForGroup },
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithGroupPinnedVersion);
      });

      it('sets initial values to project-pinned version even if group- and project-level configurations are present', async () => {
        createComponent(
          {
            aiCatalogAgent: {
              ...mockAgent,
              configurationForGroup: mockItemConfigurationForGroup,
              configurationForProject: mockAgentConfigurationForProject,
            },
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithProjectPinnedVersion);
      });

      it('sets initial values to latest version when neither the group- nor project-level configurations are present', async () => {
        createComponent(
          {
            aiCatalogAgent: {
              ...mockAgent,
              configurationForGroup: null,
              configurationForProject: null,
            },
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);
      });
    });
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockAgent;
    const formValues = {
      name: `${name} 2`,
      description,
      projectId: project.id,
      systemPrompt: 'A new system prompt',
      public: true,
      type: 'AGENT',
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    const { type, ...input } = formValues;

    beforeEach(async () => {
      await waitForPromises();
    });

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
  });
});
