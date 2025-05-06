import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';

jest.mock('~/alert');

describe('DuoWorkflowAction component', () => {
  let wrapper;

  const projectId = 123;
  const duoWorkflowInvokePath = `/api/v4/projects/${projectId}/duo_workflows`;
  const pipelineId = 987;
  const pipelinePath = `/project/${projectId}/pipelines/${pipelineId}`;

  const mockPipelineData = {
    pipeline: {
      id: pipelineId,
      path: pipelinePath,
    },
  };

  const defaultProps = {
    projectId,
    title: 'Convert to GitLab CI/CD',
    hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
    goal: 'Jenkinsfile',
    workflowDefinition: 'convert_to_gitlab_ci',
    agentPrivileges: [1, 2, 3, 4, 5],
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DuoWorkflowAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        duoWorkflowInvokePath,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    jest.spyOn(axios, 'post');
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders button with correct props', () => {
      expect(findButton().props('category')).toBe('primary');
      expect(findButton().props('icon')).toBe('tanuki-ai');
      expect(findButton().props('size')).toBe('small');
      expect(findButton().attributes('title')).toBe(defaultProps.hoverMessage);
      expect(findButton().text()).toBe(defaultProps.title);
    });
  });

  describe('startWorkflow', () => {
    const expectedRequestData = {
      project_id: projectId,
      start_workflow: true,
      goal: defaultProps.goal,
      workflow_definition: defaultProps.workflowDefinition,
      agent_privileges: defaultProps.agentPrivileges,
    };

    const pipelineHref = `<a href="${pipelinePath}">${pipelineId}</a>`;

    beforeEach(() => {
      createComponent();
    });

    it('makes API call with correct data when button is clicked', async () => {
      axios.post.mockResolvedValue({ data: mockPipelineData });

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(axios.post).toHaveBeenCalledWith(duoWorkflowInvokePath, expectedRequestData);
    });

    describe('when request succeeds', () => {
      beforeEach(() => {
        axios.post.mockResolvedValue({ data: mockPipelineData });
      });

      it('shows success alert with pipeline link', async () => {
        findButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            variant: 'success',
            data: mockPipelineData,
            renderMessageHTML: true,
            message: expect.stringContaining(pipelineHref),
          }),
        );
      });
    });

    describe('when request fails', () => {
      const error = new Error('API error');

      beforeEach(() => {
        axios.post.mockRejectedValue(error);
      });

      it('shows error alert', async () => {
        findButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the workflow',
          captureError: true,
          error,
        });
      });
    });
  });
});
