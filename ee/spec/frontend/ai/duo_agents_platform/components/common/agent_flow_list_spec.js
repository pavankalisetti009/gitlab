import { GlEmptyState, GlKeysetPagination } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentFlowListItem from 'ee/ai/duo_agents_platform/components/common/agent_flow_list_item.vue';
import { mockAgentFlows } from '../../../mocks';

describe('AgentFlowList', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findAgentFlowListItems = () => wrapper.findAllComponents(AgentFlowListItem);
  const findKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AgentFlowList, {
      propsData: {
        workflows: mockAgentFlows,
        workflowsPageInfo: {},
        ...props,
      },
    });
  };

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('and there are no workflows', () => {
      beforeEach(async () => {
        await createWrapper({ workflows: [] });
      });

      it('renders the emptyState', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyState().props()).toMatchObject({
          title: 'No agent sessions yet',
          description: 'New agent sessions will appear here.',
        });
        expect(findEmptyState().props('svgPath')).toBeDefined();
      });

      it('does not render the agent flow list items', () => {
        expect(findAgentFlowListItems()).toHaveLength(0);
      });
    });

    describe('when there are workflows', () => {
      it('render the agent flow list items', () => {
        expect(findAgentFlowListItems().length).toBeGreaterThan(0);
      });

      describe('when showProjectInfo is false', () => {
        beforeEach(() => {
          createWrapper({ showProjectInfo: false });
        });

        it('passes showProjectInfo as false to each AgentFlowListItem', () => {
          findAgentFlowListItems().wrappers.forEach((item) => {
            expect(item.props('showProjectInfo')).toBe(false);
          });
        });
      });

      describe('when showProjectInfo is true', () => {
        beforeEach(() => {
          createWrapper({ showProjectInfo: true });
        });

        it('passes showProjectInfo as true to each AgentFlowListItem', () => {
          findAgentFlowListItems().wrappers.forEach((item) => {
            expect(item.props('showProjectInfo')).toBe(true);
          });
        });
      });

      describe('when showProjectInfo is not provided', () => {
        beforeEach(() => {
          createWrapper();
        });

        it('defaults showProjectInfo to false for each AgentFlowListItem', () => {
          findAgentFlowListItems().wrappers.forEach((item) => {
            expect(item.props('showProjectInfo')).toBe(false);
          });
        });
      });
    });
  });

  describe('keyset pagination controls', () => {
    describe('when there is no pagination data', () => {
      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: {},
        });
      });

      it('renders pagination controls but they are not functional', () => {
        expect(findKeysetPagination().exists()).toBe(true);
      });
    });
    describe('when there is pagination data', () => {
      const paginationData = {
        startCursor: 'start',
        endCursor: 'end',
        hasNextPage: true,
        hasPreviousPage: false,
      };

      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: paginationData,
        });
      });

      it('renders pagination controls', () => {
        expect(findKeysetPagination().isVisible()).toBe(true);
      });

      it('binds the correct page info to pagination controls', () => {
        expect(findKeysetPagination().props()).toMatchObject(paginationData);
      });

      describe('when clicking on the next page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('next');
        });

        it('emit next-page', () => {
          expect(wrapper.emitted('next-page')).toHaveLength(1);
        });
      });

      describe('when clicking on the previous page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('prev');
        });

        it('emit prev-page', () => {
          expect(wrapper.emitted('prev-page')).toHaveLength(1);
        });
      });
    });
  });
});
