import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import FlowTriggersIndex from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/flow_triggers_index.vue';
import FlowTriggersTable from 'ee/ai/duo_agents_platform/pages/flow_triggers/index//components/flow_triggers_table.vue';
import getProjectAiFlowTriggers from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import { mockAiFlowTriggersResponse, mockEmptyAiFlowTriggersResponse } from '../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('FlowTriggersIndex', () => {
  let wrapper;
  let mockApollo;

  const mockFlowTriggerQueryHandler = jest.fn().mockResolvedValue(mockAiFlowTriggersResponse);

  const findLoadingStateList = () => wrapper.findComponent(ResourceListsLoadingStateList);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findTable = () => wrapper.findComponent(FlowTriggersTable);

  const createWrapper = ({ queryHandler = mockFlowTriggerQueryHandler } = {}) => {
    mockApollo = createMockApollo([[getProjectAiFlowTriggers, queryHandler]]);

    wrapper = shallowMountExtended(FlowTriggersIndex, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: 'myProject',
        emptyStateIllustrationPath: 'illustrations/empty-state/empty-pipeline-md.svg',
      },
    });
  };

  beforeEach(() => {
    createAlert.mockClear();
    createWrapper();
  });

  describe('Rendering', () => {
    describe('while fetching data', () => {
      it('shows a loading state', () => {
        expect(findLoadingStateList().exists()).toBe(true);
      });

      it('does not show an empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not show a table of triggers', () => {
        expect(findTable().exists()).toBe(false);
      });
    });

    describe('when the data is loaded', () => {
      describe('and there is data', () => {
        beforeEach(async () => {
          await waitForPromises();
        });

        it('fetches list data', () => {
          expect(mockFlowTriggerQueryHandler).toHaveBeenCalled();
        });

        it('shows a table of triggers', () => {
          expect(findTable().exists()).toBe(true);
        });

        it('does not show an empty state', () => {
          expect(findEmptyState().exists()).toBe(false);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });
      });

      describe('and there is no data', () => {
        beforeEach(async () => {
          createWrapper({ queryHandler: mockEmptyAiFlowTriggersResponse });
          await waitForPromises();
        });

        it('shows an empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });

        it('does not show a table of triggers', () => {
          expect(findTable().exists()).toBe(false);
        });
      });

      describe('but the request failed', () => {
        const error = new Error();

        beforeEach(async () => {
          createWrapper({ queryHandler: jest.fn().mockRejectedValue(error) });
          await waitForPromises();
        });

        it('creates an error alert', () => {
          expect(createAlert).toHaveBeenCalledWith({
            captureError: true,
            message: 'Failed to fetch flow triggers',
          });
        });

        it('shows an empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not show a loading state', () => {
          expect(findLoadingStateList().exists()).toBe(false);
        });
      });
    });
  });
});
