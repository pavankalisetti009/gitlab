import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { AgentMessage, SystemMessage } from '@gitlab/duo-ui';
import { createAlert } from '~/alert';
import WorkflowLogs from 'ee/ai/duo_agents_platform/pages/show/components/workflow_logs.vue';
import { mockWorkflowEvents } from '../../../../mocks';

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
      expect(findAllToolMessages()).toHaveLength(2);
      expect(findAllAgentMessages()).toHaveLength(1);
      expect(findAllAgentMessages().at(0).props().message).toEqual({
        content: 'I am done!',
        message_type: 'agent',
      });
    });

    it('does not render any alerts', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('with single workflow event', () => {
    beforeEach(() => {
      createComponent({ workflowEvents: [mockWorkflowEvents[0]] });
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
      expect(createAlert).toHaveBeenCalled();
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
