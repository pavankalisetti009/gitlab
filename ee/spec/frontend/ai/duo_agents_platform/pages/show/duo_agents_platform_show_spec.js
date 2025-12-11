import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import axios from '~/lib/utils/axios_utils';

import DuoAgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import AgentFlowCancelationModal from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_cancelation_modal.vue';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from 'ee/ai/duo_agents_platform/constants';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

import { mockGetAgentFlowResponse, mockDuoMessages } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils');

describe('DuoAgentsPlatformShow', () => {
  let wrapper;

  let getAgentFlowHandler;

  const agentFlowId = '1';
  const graphqlWorkflowId = convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, agentFlowId);
  const defaultMockRoute = {
    params: {
      id: agentFlowId,
    },
  };

  const createWrapper = (props = {}, mockRoute = defaultMockRoute) => {
    const handlers = [[getAgentFlow, getAgentFlowHandler]];

    wrapper = shallowMount(DuoAgentsPlatformShow, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...props,
      },
      mocks: {
        $route: mockRoute,
      },
    });

    return waitForPromises();
  };

  const findAgentFlowDetails = () => wrapper.findComponent(AgentFlowDetails);
  const findCancelConfirmationModal = () => wrapper.findComponent(AgentFlowCancelationModal);

  beforeEach(() => {
    getAgentFlowHandler = jest.fn().mockResolvedValue(mockGetAgentFlowResponse);
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the AgentFlowDetails component', () => {
      expect(findAgentFlowDetails().exists()).toBe(true);
    });

    it('passes correct props to AgentFlowDetails', () => {
      const workflowDetailsProps = findAgentFlowDetails().props();

      // Use toMatchObject instead of toEqual because Vue 3 passes through the :class binding
      // as a 'class' prop, while Vue 2 does not include it in component props
      expect(workflowDetailsProps).toMatchObject({
        isLoading: false,
        status: 'RUNNING',
        humanStatus: 'Running',
        executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/jobs/456',
        createdAt: expect.any(String),
        updatedAt: expect.any(String),
        agentFlowDefinition: 'Software development',
        duoMessages: mockDuoMessages,
        project: mockGetAgentFlowResponse.data.duoWorkflowWorkflows.edges[0].node.project,
        canUpdateWorkflow: true,
      });
    });
  });

  describe('Apollo queries', () => {
    describe('agentFlowEvents query', () => {
      describe('when loading', () => {
        beforeEach(() => {
          // Not awaiting here simulates the loading state
          createWrapper();
        });

        it('passes the loading state to the details component', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(true);
        });
      });

      describe('on successful response', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        it('fetches workflow events data with correct variables', () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);
          expect(getAgentFlowHandler).toHaveBeenCalledWith({
            workflowId: graphqlWorkflowId,
          });
        });

        it('does not show an error', () => {
          expect(createAlert).not.toHaveBeenCalled();
        });

        it('passes the loading state to the details component as false', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(false);
        });
      });

      describe('when agentFlowEvents query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: errorMessage, captureError: true });
        });
      });

      describe('when error occurs without message', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(''));
          await createWrapper();
        });

        it('calls createAlert with default error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while fetching Agent Flows',
            captureError: true,
          });
        });
      });

      describe('polling', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        it('polls after 10 seconds', async () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(3000);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(2);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(3);
        });
      });
    });
  });

  describe('route parameter handling', () => {
    it('converts route id to GraphQL ID correctly', async () => {
      const customWorkflowId = '123';

      wrapper = createWrapper(
        {},
        {
          params: {
            id: customWorkflowId,
          },
        },
      );

      await waitForPromises();

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, customWorkflowId),
      });
    });
  });

  describe('Cancel session functionality', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('confirmation modal', () => {
      it('renders the cancel session confirmation modal', () => {
        expect(findCancelConfirmationModal().exists()).toBe(true);
        expect(findCancelConfirmationModal().props('visible')).toBe(false);
        expect(findCancelConfirmationModal().props('loading')).toBe(false);
      });

      it('shows modal when cancel-session event is emitted from AgentFlowDetails', async () => {
        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);
      });

      it('hides modal when hide event is emitted', async () => {
        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);

        findCancelConfirmationModal().vm.$emit('hide');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(false);
      });
    });

    describe('session cancellation', () => {
      beforeEach(async () => {
        axios.patch = jest.fn();
        getAgentFlowHandler.mockClear();
        await createWrapper();
      });

      it('calls API to cancel session when confirmed', async () => {
        axios.patch.mockResolvedValue({ data: { status: 'STOPPED' } });

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        expect(findCancelConfirmationModal().props('visible')).toBe(true);

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(axios.patch).toHaveBeenCalledWith('/api/v4/ai/duo_workflows/workflows/1', {
          status_event: 'stop',
        });
        expect(findCancelConfirmationModal().props('visible')).toBe(false);
      });

      it('shows success alert and refetches data on successful cancellation', async () => {
        axios.patch.mockResolvedValue({ data: { status: 'STOPPED' } });

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Session has been cancelled successfully.',
          variant: 'success',
        });
        expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);
      });

      it('shows error alert on API failure', async () => {
        const errorMessage = 'Failed to cancel';
        axios.patch.mockRejectedValue({
          response: {
            status: 422,
            data: { message: errorMessage },
          },
        });

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        findCancelConfirmationModal().vm.$emit('confirm');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: errorMessage,
          captureError: true,
          variant: 'danger',
        });
      });

      it('shows loading state during cancellation', async () => {
        let resolveRequest;
        axios.patch.mockImplementation(
          () =>
            new Promise((resolve) => {
              resolveRequest = resolve;
            }),
        );

        findAgentFlowDetails().vm.$emit('cancel-session');
        await nextTick();

        const cancelPromise = findCancelConfirmationModal().vm.$emit('confirm');
        await nextTick();

        expect(findCancelConfirmationModal().props('loading')).toBe(true);

        // Resolve the promise to clean up
        resolveRequest({ data: { status: 'STOPPED' } });
        await cancelPromise;
      });
    });
  });
});
