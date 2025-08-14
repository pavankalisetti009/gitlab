import { shallowMount } from '@vue/test-utils';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import AgentFlowHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_header.vue';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';
import AgentFlowLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_logs.vue';
import { mockAgentFlowCheckpoint } from '../../../../mocks';

describe('AgentFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    status: 'RUNNING',
    agentFlowDefinition: 'software_development',
    agentFlowCheckpoint: mockAgentFlowCheckpoint,
    executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123',
    createdAt: '2023-01-01T00:54:00Z',
    updatedAt: '2024-01-02T00:34:00Z',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findAgentFlowHeader = () => wrapper.findComponent(AgentFlowHeader);
  const findAgentFlowInfo = () => wrapper.findComponent(AgentFlowInfo);
  const findAgentFlowLogs = () => wrapper.findComponent(AgentFlowLogs);

  beforeEach(() => {
    createComponent();
  });

  it('renders all tab components and their content', () => {
    expect(findAgentFlowHeader().exists()).toBe(true);
    expect(findAgentFlowInfo().exists()).toBe(true);
    expect(findAgentFlowLogs().exists()).toBe(true);
  });

  describe('props passing', () => {
    it('passes agentFlowCheckpoint to AgentFlowLogs', () => {
      expect(findAgentFlowLogs().props('agentFlowCheckpoint')).toEqual(
        defaultProps.agentFlowCheckpoint,
      );
    });

    it('passes status and workflowDefinition to AgentFlowInfo', () => {
      expect(findAgentFlowInfo().props()).toEqual({
        isLoading: false,
        status: defaultProps.status,
        agentFlowDefinition: defaultProps.agentFlowDefinition,
        executorUrl: defaultProps.executorUrl,
        createdAt: '2023-01-01T00:54:00Z',
        updatedAt: '2024-01-02T00:34:00Z',
      });
    });
  });
});
