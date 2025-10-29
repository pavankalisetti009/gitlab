import Vue, { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import getDuoWorkflowStatusCheck from 'ee/ai/graphql/get_duo_workflow_status_check.query.graphql';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import { mockCreateFlowResponse } from '../mocks';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('DuoWorkflowAction component', () => {
  let wrapper;
  let mock;

  const projectId = 1;
  const duoWorkflowInvokePath = `/api/v4/ai/duo_workflows/workflows`;
  const currentRef = 'feature-branch';
  const sourceBranch = 'source-branch';

  const defaultProps = {
    projectPath: 'group/project',
    hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
    goal: 'Jenkinsfile',
    workflowDefinition: 'convert_to_gitlab_ci',
    agentPrivileges: [1, 2, 5],
  };

  let mockGetHealthCheckHandler;

  const mockDuoWorkflowStatusCheckEnabled = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowStatusCheck: {
          enabled: true,
          remoteFlowsEnabled: true,
        },
      },
    },
  };

  const mockDuoWorkflowStatusCheckDisabled = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowStatusCheck: {
          enabled: false,
          remoteFlowsEnabled: false,
        },
      },
    },
  };

  const mockDuoWorkflowStatusCheckEnabledButRemoteFlowsDisabled = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowStatusCheck: {
          enabled: true,
          remoteFlowsEnabled: false,
        },
      },
    },
  };

  const mockDuoWorkflowStatusCheckDisabledButRemoteFlowsEnabled = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowStatusCheck: {
          enabled: false,
          remoteFlowsEnabled: true,
        },
      },
    },
  };

  const createComponent = ({ props = {}, ...options } = {}) => {
    const handlers = [[getDuoWorkflowStatusCheck, mockGetHealthCheckHandler]];

    wrapper = shallowMount(DuoWorkflowAction, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...defaultProps,
        ...props,
      },
      ...options,
    });

    return waitForPromises();
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: 'v4',
    };
    mock.onPost(duoWorkflowInvokePath).reply(() => {
      return [200, mockCreateFlowResponse];
    });
    mockGetHealthCheckHandler = jest.fn().mockResolvedValue(mockDuoWorkflowStatusCheckEnabled);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('rendering', () => {
    describe('when duoWorkflowStatusCheck is not enabled', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest.fn().mockResolvedValue(mockDuoWorkflowStatusCheckDisabled);
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('calls health checks query', () => {
        expect(mockGetHealthCheckHandler).toHaveBeenCalled();
      });
    });

    describe('when duoWorkflowStatusCheck is enabled but remoteFlowsEnabled is false', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest
          .fn()
          .mockResolvedValue(mockDuoWorkflowStatusCheckEnabledButRemoteFlowsDisabled);
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('calls health checks query', () => {
        expect(mockGetHealthCheckHandler).toHaveBeenCalled();
      });
    });

    describe('when duoWorkflowStatusCheck is disabled but remoteFlowsEnabled is true', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest
          .fn()
          .mockResolvedValue(mockDuoWorkflowStatusCheckDisabledButRemoteFlowsEnabled);
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('calls health checks query', () => {
        expect(mockGetHealthCheckHandler).toHaveBeenCalled();
      });
    });

    describe('when both duoWorkflowStatusCheck and remoteFlowsEnabled are enabled', () => {
      beforeEach(async () => {
        await createComponent({
          slots: { default: 'My button' },
        });
      });

      it('renders button with correct props', () => {
        expect(findButton().props('category')).toBe('primary');
        expect(findButton().props('icon')).toBe('tanuki-ai');
        expect(findButton().props('size')).toBe('small');
        expect(findButton().props('variant')).toBe('default');
        expect(findButton().props('loading')).toBe(false);
        expect(findButton().attributes('title')).toBe(defaultProps.hoverMessage);
        expect(findButton().text()).toBe('My button');
      });
    });

    describe('when projectPath is empty', () => {
      beforeEach(async () => {
        await createComponent({ props: { projectPath: '' } });
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });

      it('does not call health checks query', () => {
        expect(mockGetHealthCheckHandler).not.toHaveBeenCalled();
      });
    });

    describe('when duoWorkflowStatusCheck is enabled with remoteFlowsEnabled but projectId is missing', () => {
      beforeEach(async () => {
        mockGetHealthCheckHandler = jest.fn().mockResolvedValue({
          data: {
            project: {
              id: null,
              duoWorkflowStatusCheck: {
                enabled: true,
                remoteFlowsEnabled: true,
              },
            },
          },
        });
        await createComponent();
      });

      it('does not render button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });
  });

  describe('loading state', () => {
    beforeEach(async () => {
      await createComponent();
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(() => new Promise(() => {})); // Never resolves

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
        mock.onPost(duoWorkflowInvokePath).reply(500);
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
      additional_context: [],
    };

    beforeEach(async () => {
      await createComponent();
    });

    describe('when the goal fails to match the promptValidatorRegex', () => {
      const invalidGoal = 'InvalidPath';

      beforeEach(async () => {
        await createComponent({
          props: { goal: invalidGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ },
        });
        findButton().vm.$emit('click');
      });

      it('emits prompt-validation-error', () => {
        expect(wrapper.emitted('prompt-validation-error')).toEqual([[invalidGoal]]);
      });

      it('does not show loading state for validation errors', () => {
        expect(findButton().props('loading')).toBe(false);
      });

      it('does not make API call', () => {
        expect(mock.history.post).toHaveLength(0);
      });
    });

    describe('when the goal matches the promptVaidatorRegex', () => {
      const validGoal = 'Jenkinsfile';

      beforeEach(async () => {
        await createComponent({
          props: { goal: validGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ },
        });
        findButton().vm.$emit('click');
      });

      it('does not emit prompt-validation-error when goal matches regex', () => {
        expect(wrapper.emitted('prompt-validation-error')).toBeUndefined();
      });

      it('makes API call', () => {
        expect(mock.history.post).toHaveLength(1);
      });
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('makes API call with correct data', () => {
        const request = mock.history.post[0];
        expect(JSON.parse(request.data)).toEqual(expectedRequestData);
      });
    });

    describe('additionalContext handling', () => {
      describe('when additionalContext is provided', () => {
        const additionalContext = [
          {
            Category: 'agent_user_environment',
            Content: "{'merge_request_url': 'test.com'}",
            Metadata: '{}',
          },
          {
            Category: 'file_content',
            Content: 'pipeline content',
            Metadata: '{"type": "jenkins"}',
          },
        ];

        beforeEach(async () => {
          await createComponent({ props: { additionalContext } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes additional_context array in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: additionalContext,
          });
        });
      });

      describe('when additionalContext is an empty array', () => {
        const additionalContext = [];

        beforeEach(async () => {
          await createComponent({ props: { additionalContext } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes empty additional_context array in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: [],
          });
        });
      });

      describe('when additionalContext is not provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes empty array as additional_context in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            additional_context: [],
          });
        });
      });
    });

    describe('source branch handling', () => {
      describe('when currentRef is provided', () => {
        beforeEach(async () => {
          await createComponent({ provide: { currentRef } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes currentRef as source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: currentRef,
          });
        });
      });

      describe('when sourceBranch prop is provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { sourceBranch } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('includes sourceBranch as source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: sourceBranch,
          });
        });
      });

      describe('when both currentRef and sourceBranch are provided', () => {
        beforeEach(async () => {
          await createComponent({ props: { sourceBranch }, provide: { currentRef } });

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('prioritizes sourceBranch over currentRef', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual({
            ...expectedRequestData,
            source_branch: sourceBranch,
          });
        });
      });

      describe('when neither currentRef nor sourceBranch are provided', () => {
        beforeEach(async () => {
          await createComponent();

          findButton().vm.$emit('click');
          await waitForPromises();
        });

        it('does not include source_branch in the request params', () => {
          const request = mock.history.post[0];
          expect(JSON.parse(request.data)).toEqual(expectedRequestData);
        });
      });
    });

    describe('when request succeeds', () => {
      describe('side effects', () => {
        beforeEach(async () => {
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

      describe('when there is a projectPath prop', () => {
        beforeEach(async () => {
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

    describe('when request succeeds but workload fails', () => {
      const mockFailedWorkloadResponse = {
        id: 563,
        project_id: 1,
        workload: {
          id: null,
          message: 'Branch already exists',
        },
      };

      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(200, mockFailedWorkloadResponse);
        await createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert with generic message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the flow.',
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('does not emit agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
      });

      it('removes loading state after error', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when request fails', () => {
      beforeEach(async () => {
        mock.onPost(duoWorkflowInvokePath).reply(500);
        await createComponent();
        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the flow.',
          captureError: true,
          error: expect.any(Error),
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
