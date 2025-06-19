import { shallowMount } from '@vue/test-utils';
import WorkflowLogs from 'ee/ai/duo_agents_platform/pages/show/components/workflow_logs.vue';

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

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the fetching logs message', () => {
      expect(wrapper.text()).toContain('Fetching logs...');
    });
  });

  describe('with workflow events', () => {
    const workflowEvents = [
      { checkpoint: 'Starting workflow...' },
      { checkpoint: 'Processing data...' },
      { checkpoint: 'Workflow completed successfully!' },
    ];

    beforeEach(() => {
      createComponent({ workflowEvents });
    });

    it('displays the last checkpoint', () => {
      expect(wrapper.text()).toContain('Workflow completed successfully!');
    });
  });

  describe('with single workflow event', () => {
    const workflowEvents = [{ checkpoint: 'Single event checkpoint' }];

    beforeEach(() => {
      createComponent({ workflowEvents });
    });

    it('displays the single checkpoint', () => {
      expect(wrapper.text()).toContain('Single event checkpoint');
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
