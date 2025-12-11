import { shallowMount } from '@vue/test-utils';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import AgentFlowHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_header.vue';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';
import AgentFlowSubHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_sub_header.vue';
import AgentActivityLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_activity_logs.vue';

import { mockDuoMessages } from '../../../../mocks';

describe('AgentFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    status: 'RUNNING',
    humanStatus: 'Running',
    agentFlowDefinition: 'software_development',
    duoMessages: mockDuoMessages,
    executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/jobs/123',
    createdAt: '2023-01-01T00:54:00Z',
    updatedAt: '2024-01-02T00:34:00Z',
    userId: 'gid://gitlab/User/1',
    workflowId: '123',
    canUpdateWorkflow: true,
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Test Project',
      fullPath: 'gitlab-org/test-project',
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'gitlab-org',
      },
    },
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMount(AgentFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        isSidePanelView: false,
        ...provide,
      },
      stubs: {
        GlTabs: true,
        GlTab: true,
      },
    });
  };

  const findAgentFlowHeader = () => wrapper.findComponent(AgentFlowHeader);
  const findAgentFlowSubHeader = () => wrapper.findComponent(AgentFlowSubHeader);
  const findAgentFlowInfo = () => wrapper.findComponent(AgentFlowInfo);
  const findAgentActivityLogs = () => wrapper.findComponent(AgentActivityLogs);
  const findTabsContainer = () => wrapper.find('.gl-flex');

  describe('when not in side panel view', () => {
    beforeEach(() => {
      createComponent({ provide: { isSidePanelView: false } });
    });

    it('renders all tab components and their content', () => {
      expect(findAgentFlowHeader().exists()).toBe(true);
      expect(findAgentFlowInfo().exists()).toBe(true);
      expect(findAgentActivityLogs().exists()).toBe(true);
    });

    it('applies margin top class to tabs container', () => {
      expect(findTabsContainer().classes()).toContain('gl-mt-6');
    });
  });

  describe('when in side panel view', () => {
    beforeEach(() => {
      createComponent({ provide: { isSidePanelView: true } });
    });

    it('does not render the agent flow header', () => {
      expect(findAgentFlowHeader().exists()).toBe(false);
    });

    it('renders tab components without header', () => {
      expect(findAgentFlowInfo().exists()).toBe(true);
      expect(findAgentActivityLogs().exists()).toBe(true);
    });

    it('does not apply margin top class to tabs container', () => {
      expect(findTabsContainer().classes()).not.toContain('gl-mt-6');
    });
  });

  describe('props passing', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes agentFlowCheckpoint to AgentFlowLogs', () => {
      expect(findAgentActivityLogs().props('agentFlowCheckpoint')).toEqual(
        defaultProps.agentFlowCheckpoint,
      );
    });

    it('passes status and workflowDefinition to AgentFlowInfo', () => {
      expect(findAgentFlowInfo().props()).toEqual({
        isLoading: false,
        status: defaultProps.status,
        humanStatus: defaultProps.humanStatus,
        agentFlowDefinition: defaultProps.agentFlowDefinition,
        executorUrl: defaultProps.executorUrl,
        createdAt: '2023-01-01T00:54:00Z',
        updatedAt: '2024-01-02T00:34:00Z',
        project: defaultProps.project,
        canUpdateWorkflow: true,
      });
    });

    it('passes correct props to AgentFlowHeader when not in side panel', () => {
      expect(findAgentFlowHeader().props()).toEqual({
        isLoading: false,
        agentFlowDefinition: defaultProps.agentFlowDefinition,
      });
    });

    it('passes correct props to AgentFlowSubHeader when not in side panel', () => {
      expect(findAgentFlowSubHeader().props()).toEqual({
        isLoading: false,
        agentFlowDefinition: defaultProps.agentFlowDefinition,
        createdAt: defaultProps.createdAt,
        userId: defaultProps.userId,
      });
    });
  });
});
