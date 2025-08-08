import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import { mockCreateFlowResponse } from '../mocks';

jest.mock('~/alert');

describe('DuoWorkflowAction component', () => {
  let wrapper;

  const projectId = 123;
  const duoWorkflowInvokePath = `/api/v4/projects/${projectId}/duo_workflows`;
  const currentRef = 'feature-branch';

  const defaultProps = {
    projectId,
    projectPath: 'group/project',
    title: 'Convert to GitLab CI/CD',
    hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
    goal: 'Jenkinsfile',
    workflowDefinition: 'convert_to_gitlab_ci',
    agentPrivileges: [1, 2, 5],
    duoWorkflowInvokePath,
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMount(DuoWorkflowAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    jest.spyOn(axios, 'post');
    axios.post.mockResolvedValue({ data: mockCreateFlowResponse });
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders button with correct props', () => {
      expect(findButton().props('category')).toBe('primary');
      expect(findButton().props('icon')).toBe('tanuki-ai');
      expect(findButton().props('size')).toBe('small');
      expect(findButton().props('loading')).toBe(false);
      expect(findButton().attributes('title')).toBe(defaultProps.hoverMessage);
      expect(findButton().text()).toBe(defaultProps.title);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        axios.post.mockImplementation(() => new Promise(() => {})); // Never resolves

        findButton().vm.$emit('click');
        await nextTick();
      });

      it('shows loading state', () => {
        expect(findButton().props('loading')).toBe(true);
      });
    });

    describe('when the flow starts successfully', () => {
      beforeEach(async () => {
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('removes loading state when workflow starts successfully', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when the flow fails to start', () => {
      beforeEach(async () => {
        const error = new Error('API error');

        axios.post.mockRejectedValue(error);
        findButton().vm.$emit('click');

        await waitForPromises();
      });
      it('removes loading state when workflow fails to start', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });
  });

  describe('startWorkflow', () => {
    const expectedRequestData = {
      project_id: projectId,
      start_workflow: true,
      environment: 'web',
      goal: defaultProps.goal,
      workflow_definition: defaultProps.workflowDefinition,
      agent_privileges: defaultProps.agentPrivileges,
    };

    describe('when the goal fails to match the promptValidatorRegex', () => {
      const invalidGoal = 'InvalidPath';

      beforeEach(() => {
        createComponent({ goal: invalidGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ });
        findButton().vm.$emit('click');
      });

      it('emits prompt-validation-error', () => {
        expect(wrapper.emitted('prompt-validation-error')).toEqual([[invalidGoal]]);
        expect(axios.post).not.toHaveBeenCalled();
      });

      it('does not show loading state for validation errors', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when the goal matches the promptVaidatorRegex', () => {
      const validGoal = 'Jenkinsfile';

      beforeEach(() => {
        createComponent({ goal: validGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ });
        findButton().vm.$emit('click');
      });

      it('does not emit prompt-validation-error when goal matches regex', () => {
        expect(wrapper.emitted('prompt-validation-error')).toBeUndefined();
        expect(axios.post).toHaveBeenCalled();
      });
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('makes API call with correct data', () => {
        expect(axios.post).toHaveBeenCalledWith(duoWorkflowInvokePath, expectedRequestData);
      });
    });

    describe('when currentRef is provided', () => {
      beforeEach(async () => {
        createComponent({}, { currentRef });

        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('includes source_branch in the request params', () => {
        expect(axios.post).toHaveBeenCalledWith(duoWorkflowInvokePath, {
          ...expectedRequestData,
          source_branch: currentRef,
        });
      });
    });

    describe('when request succeeds', () => {
      describe('side effects', () => {
        beforeEach(async () => {
          createComponent();
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('emits agent-flow-started event', () => {
          expect(wrapper.emitted('agent-flow-started')).toEqual([[mockCreateFlowResponse]]);
        });

        it('removes loading state after success', () => {
          expect(findButton().props('loading')).toBe(false);
        });
      });

      describe('when there are no projectPath prop', () => {
        beforeEach(async () => {
          createComponent({ projectPath: null });
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('calls createAlert without messageLinks', () => {
          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({ message: 'Flow started successfully.', messageLinks: {} }),
          );
        });
      });

      describe('when there is a projectPath prop', () => {
        beforeEach(async () => {
          createComponent();
          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('shows success alert with the session ID', () => {
          expect(createAlert).toHaveBeenCalledWith(
            expect.objectContaining({
              variant: 'success',
              message:
                'Flow started successfully. To view progress, see %{linkStart}Session 1056241%{linkEnd}.',
              messageLinks: {
                link: '/group/project/-/automate/agent-sessions/1056241',
              },
            }),
          );
        });
      });
    });

    describe('when request fails', () => {
      const error = new Error('API error');

      beforeEach(async () => {
        axios.post.mockRejectedValue(error);
        createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the flow.',
          captureError: true,
          error,
        });
      });

      it('does not emits agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
      });

      it('removes loading state after error', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });
  });
});
