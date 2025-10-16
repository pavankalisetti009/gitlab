import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogAgentsEdit from 'ee/ai/catalog/pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import updateAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockUpdateAiCatalogAgentSuccessMutation,
  mockUpdateAiCatalogAgentErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogAgentsEdit', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    aiCatalogAgent: mockAgent,
  };
  const agentId = 1;
  const routeParams = { id: agentId };
  const mockToast = {
    show: jest.fn(),
  };
  const mockRouter = {
    push: jest.fn(),
  };

  const mockUpdateAiCatalogAgentHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogAgentSuccessMutation);

  const createComponent = () => {
    mockApollo = createMockApollo([[updateAiCatalogAgent, mockUpdateAiCatalogAgentHandler]]);

    wrapper = shallowMount(AiCatalogAgentsEdit, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
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

  beforeEach(() => {
    createComponent();
  });

  it('render edit form', () => {
    expect(findForm().exists()).toBe(true);
  });

  describe('Form Submit', () => {
    const { name, description, systemPrompt, userPrompt, public: publicAgent } = mockAgent;
    const formValues = {
      name,
      description,
      systemPrompt,
      userPrompt,
      public: publicAgent,
    };

    const submitForm = () => findForm().vm.$emit('submit', formValues);

    it('sends an update request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      expect(mockUpdateAiCatalogAgentHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogAgentHandler).toHaveBeenCalledWith({
        input: { ...formValues, id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, agentId) },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await findForm().vm.$emit('submit', {});
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        submitForm();
        await waitForPromises();
      });

      it('shows toast', () => {
        expect(mockToast.show).toHaveBeenCalledWith('Agent updated.');
      });

      it('navigates to agents show page', async () => {
        await waitForPromises();
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
      beforeEach(async () => {
        mockUpdateAiCatalogAgentHandler.mockResolvedValue(mockUpdateAiCatalogAgentErrorMutation);
        submitForm();
        await waitForPromises();
      });

      it('shows an alert', () => {
        expect(findForm().props('errors')).toEqual([
          mockUpdateAiCatalogAgentErrorMutation.data.aiCatalogAgentUpdate.errors[0],
        ]);
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });
});
