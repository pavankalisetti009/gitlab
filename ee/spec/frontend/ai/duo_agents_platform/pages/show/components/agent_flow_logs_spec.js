import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { MessageMap } from '@gitlab/duo-ui';
import { createAlert } from '~/alert';
import AgentFlowLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_logs.vue';
import { mockAgentFlowCheckpoint } from '../../../../mocks';

jest.mock('~/alert');

describe('AgentFlowLogs', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowLogs, {
      propsData: {
        isLoading: false,
        agentFlowCheckpoint: '',
        ...props,
      },
    });
  };

  const findAllMessages = () => wrapper.findAllComponents(MessageMap);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the fetching logs message', () => {
      expect(wrapper.text()).toContain('Fetching logs...');
    });

    it('does not render any alerts', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when loaded', () => {
    describe('and there are no logs', () => {
      beforeEach(() => {
        createComponent({ agentFlowCheckpoint: '' });
      });

      it('displays fallback message when no events', () => {
        expect(wrapper.text()).toContain('No logs available yet.');
      });

      it('does not render any alerts', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });
  });

  describe('with workflow events', () => {
    beforeEach(() => {
      createComponent({ agentFlowCheckpoint: mockAgentFlowCheckpoint });
    });

    it('displays all messages in the ui_chat_log', () => {
      // There are 4 tool calls in the mocks
      expect(findAllMessages()).toHaveLength(6);
      expect(findAllMessages().at(0).props().message).toEqual({
        additional_context: null,
        content: 'Starting workflow with goal: Hello world i nJS',
        context_elements: null,
        correlation_id: null,
        message_sub_type: null,
        message_type: 'tool',
        status: 'success',
        timestamp: '2025-07-03T13:24:14.467716+00:00',
        tool_info: null,
      });
    });

    it('does not render any alerts', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when the workflow data cannot be parsed from JSON', () => {
    beforeEach(async () => {
      createComponent({ agentFlowCheckpoint: 'asdasdsa' });
      await nextTick();
    });

    it('shows error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not display logs. Please try again.',
      });
    });
  });

  describe('with empty string', () => {
    beforeEach(() => {
      createComponent({ agentFlowCheckpoint: '' });
    });

    it('displays fallback message when no events', () => {
      expect(wrapper.text()).toContain('No logs available yet.');
    });
  });
});
