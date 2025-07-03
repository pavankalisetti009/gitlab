import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { AgentMessage, SystemMessage } from '@gitlab/duo-ui';
import { createAlert } from '~/alert';
import WorkflowLogs from 'ee/ai/duo_agents_platform/pages/show/components/workflow_logs.vue';
import { mockWorkflowEvents, checkpoint1 } from '../../../../mocks';

jest.mock('~/alert');

describe('WorkflowLogs', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WorkflowLogs, {
      propsData: {
        isLoading: false,
        workflowEvents: [],
        ...props,
      },
    });
  };

  const findAllToolMessages = () => wrapper.findAllComponents(SystemMessage);
  const findAllAgentMessages = () => wrapper.findAllComponents(AgentMessage);

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
        createComponent({ workflowEvents: [] });
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
      createComponent({ workflowEvents: mockWorkflowEvents });
    });

    it('displays all messages in the ui_chat_log', () => {
      // There are 4 tool calls in the mocks
      expect(findAllToolMessages()).toHaveLength(4);
      // There are 2 agents calls in the mocks
      expect(findAllAgentMessages()).toHaveLength(2);
      expect(findAllAgentMessages().at(0).props().message).toEqual({
        additional_context: null,
        content:
          'I\'ll help you explore the GitLab project to understand the context for "Hello world in JS". Let me start by checking the current working directory and gathering information about the project structure.',
        context_elements: null,
        correlation_id: null,
        message_sub_type: null,
        message_type: 'agent',
        status: 'success',
        timestamp: '2025-07-03T13:24:18.019182+00:00',
        tool_info: null,
      });
    });

    it('does not render any alerts', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('with single workflow event', () => {
    beforeEach(() => {
      createComponent({ workflowEvents: [{ checkpoint: checkpoint1 }] });
    });

    it('displays the single checkpoint', () => {
      expect(findAllToolMessages()).toHaveLength(1);
      expect(findAllToolMessages().at(0).props().message).toEqual({
        content: 'Starting workflow...',
        message_type: 'tool',
      });
    });
  });

  describe('when the workflow data cannot be parsed from JSON', () => {
    beforeEach(async () => {
      createComponent({ workflowEvents: [{ checkpoint: {} }] });
      await nextTick();
    });

    it('shows error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not display logs. Please try again.',
      });
    });
  });

  describe('with empty workflow events', () => {
    beforeEach(() => {
      createComponent({ workflowEvents: [] });
    });

    it('displays fallback message when no events', () => {
      expect(wrapper.text()).toContain('No logs available yet.');
    });
  });
});
