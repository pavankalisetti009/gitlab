import { shallowMount } from '@vue/test-utils';
import WorkflowDetails from 'ee/ai/duo_agents_platform/pages/show/components/workflow_details.vue';
import WorkflowHeader from 'ee/ai/duo_agents_platform/pages/show/components/workflow_header.vue';
import WorkflowInfo from 'ee/ai/duo_agents_platform/pages/show/components/workflow_info.vue';
import WorkflowLogs from 'ee/ai/duo_agents_platform/pages/show/components/workflow_logs.vue';

describe('WorkflowDetails', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    prompt: 'Test prompt',
    status: 'RUNNING',
    workflowDefinition: 'software_development',
    workflowEvents: [{ checkpoint: 'Event 1' }, { checkpoint: 'Event 2' }],
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(WorkflowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findWorkflowHeader = () => wrapper.findComponent(WorkflowHeader);
  const findWorkflowInfo = () => wrapper.findComponent(WorkflowInfo);
  const findWorkflowLogs = () => wrapper.findComponent(WorkflowLogs);

  beforeEach(() => {
    createComponent();
  });

  describe('component structure', () => {
    it('renders all child components', () => {
      expect(findWorkflowHeader().exists()).toBe(true);
      expect(findWorkflowInfo().exists()).toBe(true);
      expect(findWorkflowLogs().exists()).toBe(true);
    });
  });

  describe('props passing', () => {
    it('passes prompt to WorkflowHeader', () => {
      expect(findWorkflowHeader().props('prompt')).toBe(defaultProps.prompt);
    });

    it('passes workflowEvents to WorkflowLogs', () => {
      expect(findWorkflowLogs().props('workflowEvents')).toEqual(defaultProps.workflowEvents);
    });

    it('passes status and workflowDefinition to WorkflowInfo', () => {
      expect(findWorkflowInfo().props()).toEqual({
        isLoading: false,
        status: defaultProps.status,
        workflowDefinition: defaultProps.workflowDefinition,
      });
    });
  });
});
