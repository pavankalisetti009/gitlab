import { shallowMount } from '@vue/test-utils';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import MrWidgetPipelineDuoAction from 'ee/vue_merge_request_widget/components/mr_duo_fix_pipeline.vue';
import { AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';

describe('MrWidgetPipelineDuoAction', () => {
  let wrapper;

  const defaultProps = {
    pipeline: {
      id: 172,
      path: '/gitlab-org/gitlab/pipelines/172',
    },
    targetProjectFullPath: 'gitlab-org/gitlab',
    sourceBranch: 'feature-branch',
    mergeRequestPath: '/gitlab-org/gitlab/-/merge_requests/1',
  };

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  const createWrapper = (props = {}, options = {}) => {
    wrapper = shallowMount(MrWidgetPipelineDuoAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      ...options,
    });
  };

  beforeEach(() => {
    window.gon = { gitlab_url: 'http://test.host' };
  });

  afterEach(() => {
    delete window.gon;
  });

  describe('DuoWorkflowAction rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the DuoWorkflowAction component', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
      expect(findDuoWorkflowAction().text()).toBe('Fix pipeline with Duo');
    });

    it('passes the correct props to DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().props()).toEqual({
        workflowDefinition: 'fix_pipeline/v1',
        goal: 'http://test.host/gitlab-org/gitlab/pipelines/172',
        projectPath: 'gitlab-org/gitlab',
        hoverMessage: 'Fix pipeline with Duo',
        sourceBranch: 'feature-branch',
        agentPrivileges: [
          AGENT_PRIVILEGES.READ_WRITE_FILES,
          AGENT_PRIVILEGES.READ_ONLY_GITLAB,
          AGENT_PRIVILEGES.READ_WRITE_GITLAB,
          AGENT_PRIVILEGES.USE_GIT,
        ],
        additionalContext: [
          {
            Category: 'merge_request',
            Content: JSON.stringify({
              url: 'http://test.host/gitlab-org/gitlab/-/merge_requests/1',
            }),
          },
          {
            Category: 'pipeline',
            Content: JSON.stringify({
              source_branch: 'feature-branch',
            }),
          },
        ],
        size: 'small',
        variant: 'default',
        promptValidatorRegex: null,
      });
    });
  });
});
