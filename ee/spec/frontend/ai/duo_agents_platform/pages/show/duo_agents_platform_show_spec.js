import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import DuoAgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';
import WorkflowDetails from 'ee/ai/duo_agents_platform/pages/show/components/workflow_details.vue';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from 'ee/ai/duo_agents_platform/constants';
import { getDuoWorkflowEventsQuery } from 'ee/ai/duo_agents_platform/graphql/queries/get_duo_workflow_events.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

import { mockWorkflowEventsResponse } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('DuoAgentsPlatformShow', () => {
  let wrapper;
  let mockRoute;
  let workflowEventsHandler;

  const workflowId = '1';
  const graphqlWorkflowId = convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, workflowId);

  const createWrapper = (props = {}) => {
    mockRoute = {
      params: {
        id: workflowId,
      },
    };

    const handlers = [[getDuoWorkflowEventsQuery, workflowEventsHandler]];

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

  const findWorkflowDetails = () => wrapper.findComponent(WorkflowDetails);

  beforeEach(() => {
    workflowEventsHandler = jest.fn().mockResolvedValue(mockWorkflowEventsResponse);
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the WorkflowDetails component', () => {
      expect(findWorkflowDetails().exists()).toBe(true);
    });

    it('passes correct props to WorkflowDetails', () => {
      const workflowDetailsProps = findWorkflowDetails().props();

      expect(workflowDetailsProps).toEqual({
        isLoading: false,
        status: 'Running',
        workflowDefinition: 'Software development',
        workflowEvents: mockWorkflowEventsResponse.data.duoWorkflowEvents.nodes,
      });
    });
  });

  describe('Apollo queries', () => {
    describe('workflowEvents query', () => {
      describe('when loading', () => {
        beforeEach(() => {
          // Not awaiting here simulates the loading state
          createWrapper();
        });

        it('passes the loading state to the details component', () => {
          expect(findWorkflowDetails().props().isLoading).toBe(true);
        });
      });

      describe('on successful response', () => {
        beforeEach(async () => {
          workflowEventsHandler.mockResolvedValue(mockWorkflowEventsResponse);
          await createWrapper();
        });

        it('fetches workflow events data with correct variables', () => {
          expect(workflowEventsHandler).toHaveBeenCalledTimes(1);
          expect(workflowEventsHandler).toHaveBeenCalledWith({
            workflowId: graphqlWorkflowId,
          });
        });

        it('does not show an error', () => {
          expect(createAlert).not.toHaveBeenCalled();
        });

        it('passes the loading state to the details component as false', () => {
          expect(findWorkflowDetails().props().isLoading).toBe(false);
        });
      });

      describe('when workflowEvents query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          workflowEventsHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: errorMessage });
        });
      });

      describe('when error occurs without message', () => {
        beforeEach(async () => {
          workflowEventsHandler.mockRejectedValue(new Error(''));
          await createWrapper();
        });

        it('calls createAlert with default error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while fetching Agent Flows',
          });
        });
      });

      describe('polling', () => {
        beforeEach(async () => {
          workflowEventsHandler.mockResolvedValue(mockWorkflowEventsResponse);
          await createWrapper();
        });

        it('polls after 10 seconds', async () => {
          expect(workflowEventsHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(3000);
          await waitForPromises();

          expect(workflowEventsHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(workflowEventsHandler).toHaveBeenCalledTimes(2);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(workflowEventsHandler).toHaveBeenCalledTimes(3);
        });
      });
    });
  });

  describe('route parameter handling', () => {
    it('converts route id to GraphQL ID correctly', async () => {
      const customWorkflowId = '123';
      mockRoute = {
        params: {
          id: customWorkflowId,
        },
      };

      const handlers = [[getDuoWorkflowEventsQuery, workflowEventsHandler]];

      wrapper = shallowMount(DuoAgentsPlatformShow, {
        apolloProvider: createMockApollo(handlers),
        mocks: {
          $route: mockRoute,
        },
      });

      await waitForPromises();

      expect(workflowEventsHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, customWorkflowId),
      });
    });
  });
});
