import { shallowMount } from '@vue/test-utils';
import BlobHeader from 'ee/blob/components/blob_header.vue';
import CeBlobHeader from '~/blob/components/blob_header.vue';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

jest.mock('~/graphql_shared/utils', () => ({
  getIdFromGraphQLId: jest.fn().mockReturnValue(123),
}));

describe('EE Blob Header', () => {
  let wrapper;

  const testBlob = {
    path: 'test/path.js',
    rawPath: '/raw/test/path.js',
    externalStorageUrl: null,
  };
  const testProps = {
    blob: testBlob,
    projectId: 'gid://gitlab/Project/123',
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMount(BlobHeader, {
      propsData: {
        ...testProps,
        ...props,
      },
      provide: {
        showDuoWorkflowAction: false,
        duoWorkflowInvokePath: '/api/duo/workflow',
        ...provide,
      },
    });
  };

  const findCeBlobHeader = () => wrapper.findComponent(CeBlobHeader);
  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes all props to CE component', () => {
      expect(findCeBlobHeader().props()).toMatchObject(testProps);
    });

    it('does not render DuoWorkflowAction by default', () => {
      expect(findDuoWorkflowAction().exists()).toBe(false);
    });
  });

  describe('when showDuoWorkflowAction is true', () => {
    beforeEach(() => {
      createComponent({}, { showDuoWorkflowAction: true });
    });

    it('renders the DuoWorkflowAction component', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
    });

    it('passes correct props to DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().props()).toMatchObject({
        projectId: 123,
        title: 'Convert to GitLab CI/CD',
        hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
        goal: 'Jenkinsfile',
        workflowDefinition: 'convert_to_gitlab_ci',
        agentPrivileges: [1, 2, 3, 4, 5],
      });

      expect(getIdFromGraphQLId).toHaveBeenCalledWith('gid://gitlab/Project/123');
    });
  });

  describe('slot passing', () => {
    it('passes slots to CE component', () => {
      const prependContent = 'Prepend content';
      const actionsContent = 'Actions content';

      wrapper = shallowMount(BlobHeader, {
        propsData: testProps,
        slots: {
          prepend: `<div>${prependContent}</div>`,
          actions: `<div>${actionsContent}</div>`,
        },
      });

      expect(wrapper.html()).toContain(prependContent);
      expect(wrapper.html()).toContain(actionsContent);
    });
  });
});
