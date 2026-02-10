import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogAgentsEdit from 'ee/ai/catalog/pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import updateAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import updateAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockVersionProp,
  mockAgentConfigurationForProject,
  mockUpdateAiCatalogAgentSuccessMutation,
  mockUpdateAiCatalogAgentNoChangeMutation,
  mockUpdateAiCatalogAgentMetadataOnlyMutation,
  mockUpdateAiCatalogAgentErrorMutation,
  mockUpdateAiCatalogThirdPartyFlowSuccessMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsEdit', () => {
  let wrapper;
  let mockApollo;

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
    version: mockVersionProp, // mock defaults to `latestVersion`,
  };

  const mockUpdateAiCatalogAgentHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogAgentSuccessMutation);

  const mockUpdateAiCatalogThirdPartyFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogThirdPartyFlowSuccessMutation);

  const createComponent = (props) => {
    mockApollo = createMockApollo([
      [updateAiCatalogAgent, mockUpdateAiCatalogAgentHandler],
      [updateAiCatalogThirdPartyFlow, mockUpdateAiCatalogThirdPartyFlowHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogAgentsEdit, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlLink,
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
  const findEditingLatestVersionWarning = () => wrapper.findComponent(GlAlert);
  const findEditVersionWarningText = () =>
    findEditingLatestVersionWarning().findComponent(GlSprintf).attributes('message');

  describe('Initial Rendering', () => {
    it('render edit form', () => {
      createComponent();
      expect(findForm().exists()).toBe(true);
    });

    it('renders correct version data as initial values', async () => {
      const expectedInitialValues = {
        name: mockAgent.name,
        description: mockAgent.description,
        projectId: 'gid://gitlab/Project/1',
        systemPrompt: mockAgent.latestVersion.systemPrompt,
        tools: [],
        itemType: 'AGENT',
        public: true,
      };

      createComponent({
        aiCatalogAgent: {
          ...mockAgent,
          configurationForProject: mockAgentConfigurationForProject, // this is not expected
        },
      });
      await waitForPromises();

      expect(findForm().props('initialValues')).toEqual(expectedInitialValues);
    });
  });

  describe('version update availability behaviour', () => {
    it('shows warning when version update is available', async () => {
      createComponent({
        version: {
          isUpdateAvailable: true,
        },
      });
      await waitForPromises();

      expect(findEditingLatestVersionWarning().exists()).toBe(true);
      expect(findEditVersionWarningText()).toContain(
        'To prevent versioning issues, you can edit only the latest version of this agent. To edit an earlier version,',
      );
      expect(findEditVersionWarningText()).toContain('duplicate the agent');
    });

    it('does not show warning when item is at the latest version already', async () => {
      createComponent({
        version: {
          isUpdateAvailable: false,
        },
      });
      await waitForPromises();

      expect(findEditingLatestVersionWarning().exists()).toBe(false);
    });
  });

  describe('Form Submit', () => {
    const {
      name,
      description,
      systemPrompt,
      userPrompt,
      public: publicAgent,
      itemType,
    } = mockAgent;

    const input = {
      name,
      description,
      systemPrompt,
      userPrompt,
      public: publicAgent,
    };

    const formValues = { ...input, itemType };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    beforeEach(() => {
      createComponent();
    });

    it('sends an update request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      expect(mockUpdateAiCatalogAgentHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogAgentHandler).toHaveBeenCalledWith({
        input: { ...input, id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, agentId) },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await submitForm();
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds with version change', () => {
      it('shows toast when version was updated', async () => {
        submitForm();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agent updated.');
      });
    });

    describe('when request succeeds with metadata change only', () => {
      it('shows toast when metadata was updated', async () => {
        mockUpdateAiCatalogAgentHandler.mockResolvedValue(
          mockUpdateAiCatalogAgentMetadataOnlyMutation,
        );
        submitForm();
        await waitForPromises();

        expect(mockToast.show).toHaveBeenCalledWith('Agent updated.');
      });
    });

    describe('when request succeeds without any change', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogAgentHandler.mockResolvedValue(mockUpdateAiCatalogAgentNoChangeMutation);
        submitForm();
        await waitForPromises();
      });

      it('does not show toast when nothing was updated', () => {
        expect(mockToast.show).not.toHaveBeenCalled();
      });

      it('navigates to agents show page', () => {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_SHOW_ROUTE,
          params: { id: 1 },
        });
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        mockUpdateAiCatalogAgentHandler.mockRejectedValue(new Error());
        submitForm();
        await waitForPromises();
      });

      it('sets error messages and captures exception', () => {
        expect(findForm().props('errors')).toEqual(['Could not update agent. Try again.']);
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        expect(findForm().props('isLoading')).toBe(false);
      });

      it('allows user to dismiss errors', async () => {
        await findForm().vm.$emit('dismiss-errors');

        expect(findForm().props('errors')).toEqual([]);
      });
    });

    describe('when request succeeds but returns error', () => {
      it('shows an alert', async () => {
        mockUpdateAiCatalogAgentHandler.mockResolvedValue(mockUpdateAiCatalogAgentErrorMutation);
        submitForm();
        await waitForPromises();

        expect(findForm().props('errors')).toEqual([
          mockUpdateAiCatalogAgentErrorMutation.data.aiCatalogAgentUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });

  describe('created hook - redirect behavior', () => {
    it.each([
      {
        name: 'redirects when adminAiCatalogItem is false',
        adminAiCatalogItem: false,
        shouldRedirect: true,
      },
      {
        name: 'does not redirect when adminAiCatalogItem is true',
        adminAiCatalogItem: true,
        shouldRedirect: false,
      },
    ])('$name', ({ adminAiCatalogItem, shouldRedirect }) => {
      createComponent({
        aiCatalogAgent: { ...mockAgent, userPermissions: { adminAiCatalogItem } },
      });

      if (shouldRedirect) {
        expect(mockRouter.push).toHaveBeenCalledWith({
          name: AI_CATALOG_AGENTS_SHOW_ROUTE,
          params: { id: agentId },
        });
      } else {
        expect(mockRouter.push).not.toHaveBeenCalled();
      }
    });
  });
});
