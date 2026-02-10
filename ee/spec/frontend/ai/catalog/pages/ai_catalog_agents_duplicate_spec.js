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
import { VERSION_PINNED, VERSION_PINNED_GROUP, VERSION_LATEST } from 'ee/ai/catalog/constants';
import * as utils from 'ee/ai/catalog/utils';
import {
  mockAgent,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogThirdPartyFlowSuccessMutation,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockAgentVersion,
  mockAgentPinnedVersion,
  mockAgentGroupPinnedVersion,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsDuplicate', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let createAiCatalogThirdPartyFlowMock;
  let resolveVersionSpy;

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

  const createComponent = (props = {}, provide = {}, mocks = {}) => {
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
        ...mocks,
      },
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogAgentForm);
  const findFormInitialValues = () => findForm().props('initialValues');

  beforeEach(() => {
    resolveVersionSpy = jest.spyOn(utils, 'resolveVersion').mockReturnValue({
      ...mockAgentVersion,
      key: VERSION_LATEST,
    });
  });

  afterEach(() => {
    resolveVersionSpy.mockRestore();
  });

  describe('Form Initial Values', () => {
    const baseExpectedInitialValues = {
      name: `Copy of ${mockAgent.name}`,
      description: mockAgent.description,
      itemType: 'AGENT',
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
      resolveVersionSpy.mockReturnValue({
        ...mockAgentPinnedVersion,
        key: VERSION_PINNED,
      });

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

      expect(resolveVersionSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          id: mockAgent.id,
          name: mockAgent.name,
          itemType: mockAgent.itemType,
        }),
        false,
      );
    });

    describe('being set correctly in global context', () => {
      it('sets initial values to latest version', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogAgent = {
          ...mockAgent,
          configurationForProject: mockAgentConfigurationForProject, // not expected
        };

        createComponent(
          {
            aiCatalogAgent,
          },
          {
            isGlobal: true,
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogAgent),
          true,
        );
      });
    });

    describe('being set correctly in project context', () => {
      it('sets initial values to latest version when no configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentVersion,
          key: VERSION_LATEST,
        });

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

        expect(resolveVersionSpy).toHaveBeenCalledWith(expect.objectContaining(mockAgent), false);
      });

      it('sets initial values to group-pinned version when only group configuration is present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentGroupPinnedVersion,
          key: VERSION_PINNED_GROUP,
        });

        const aiCatalogAgent = {
          ...mockAgent,
          configurationForGroup: mockItemConfigurationForGroup,
        };

        createComponent(
          {
            aiCatalogAgent,
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithGroupPinnedVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogAgent),
          false,
        );
      });

      it('sets initial values to project-pinned version even if group- and project-level configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentPinnedVersion,
          key: VERSION_PINNED,
        });

        const aiCatalogAgent = {
          ...mockAgent,
          configurationForGroup: mockItemConfigurationForGroup,
          configurationForProject: mockAgentConfigurationForProject,
        };

        createComponent(
          {
            aiCatalogAgent,
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithProjectPinnedVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogAgent),
          false,
        );
      });

      it('sets initial values to latest version when neither the group- nor project-level configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogAgent = {
          ...mockAgent,
          configurationForGroup: null,
          configurationForProject: null,
        };

        createComponent(
          {
            aiCatalogAgent,
          },
          {
            isGlobal: false,
            projectId: '1',
          },
        );
        await waitForPromises();

        expect(findFormInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);

        expect(resolveVersionSpy).toHaveBeenCalledWith(
          expect.objectContaining(aiCatalogAgent),
          false,
        );
      });
    });
  });

  describe('Form Submit', () => {
    const { name, description, project } = mockAgent;
    const input = {
      name: `${name} 2`,
      description,
      projectId: project.id,
      systemPrompt: 'A new system prompt',
      public: true,
    };

    const submitForm = () => findForm().vm.$emit('submit', { itemType: 'AGENT', ...input });

    beforeEach(async () => {
      createComponent();
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

  describe('created hook - redirect behavior', () => {
    it.each([
      {
        name: 'allows duplication in global area with admin permissions',
        isGlobal: true,
        isThirdPartyFlow: false,
        isCreateThirdPartyFlowsAvailable: true,
        userPermissions: { adminAiCatalogItem: true },
        shouldRedirect: false,
      },
      {
        name: 'allows duplication in global area without admin permissions',
        isGlobal: true,
        isThirdPartyFlow: false,
        isCreateThirdPartyFlowsAvailable: true,
        userPermissions: { adminAiCatalogItem: false },
        shouldRedirect: false,
      },
      {
        name: 'allows duplication in non-global area with admin permissions',
        isGlobal: false,
        isThirdPartyFlow: false,
        isCreateThirdPartyFlowsAvailable: true,
        userPermissions: { adminAiCatalogItem: true },
        shouldRedirect: false,
      },
      {
        name: 'redirects in non-global area without admin permissions',
        isGlobal: false,
        isThirdPartyFlow: false,
        isCreateThirdPartyFlowsAvailable: true,
        userPermissions: { adminAiCatalogItem: false },
        shouldRedirect: true,
      },
      {
        name: 'redirects when duplicating an external agent with create feature disabled',
        isGlobal: true,
        isThirdPartyFlow: true,
        isCreateThirdPartyFlowsAvailable: false,
        userPermissions: { adminAiCatalogItem: true },
        shouldRedirect: true,
      },
    ])(
      '$name',
      ({
        isGlobal,
        isThirdPartyFlow,
        isCreateThirdPartyFlowsAvailable,
        userPermissions,
        shouldRedirect,
      }) => {
        const itemType = isThirdPartyFlow ? 'THIRD_PARTY_FLOW' : 'AGENT';
        const agent = {
          ...mockAgent,
          itemType,
          userPermissions,
        };

        createComponent(
          { aiCatalogAgent: agent },
          { isGlobal },
          {
            glAbilities: {
              createAiCatalogThirdPartyFlow: isCreateThirdPartyFlowsAvailable,
            },
            glFeatures: {
              aiCatalogThirdPartyFlows: isCreateThirdPartyFlowsAvailable,
              aiCatalogCreateThirdPartyFlows: isCreateThirdPartyFlowsAvailable,
            },
          },
        );

        if (shouldRedirect) {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: agentId },
          });
        } else {
          expect(mockRouter.push).not.toHaveBeenCalled();
        }
      },
    );
  });
});
