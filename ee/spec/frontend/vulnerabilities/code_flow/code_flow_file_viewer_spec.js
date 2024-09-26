import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import CodeFlowFileViewer from 'ee/vue_shared/components/code_flow/code_flow_file_viewer.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilityFileContentViewer from 'ee/vulnerabilities/components/vulnerability_file_content_viewer.vue';
import BlobHeader from '~/blob/components/blob_header.vue';

Vue.use(VueApollo);

describe('Vulnerability Code Flow File Viewer component', () => {
  let wrapper;

  const blobData = {
    id: 1,
    rawTextBlob: 'line 1\nline 2\nline 3\nline 4\nline 5',
  };

  const defaultProps = {
    blobInfo: { rawTextBlob: blobData.rawTextBlob },
    filePath: 'samples/test.js',
    branchRef: '123',
    hlInfo: [],
  };

  const hlInfo = [
    {
      blockStartLine: 1,
      blockEndLine: 3,
      highlightInfo: [
        {
          index: 0,
          startLine: 1,
          endLine: 2,
        },
      ],
    },
  ];

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(CodeFlowFileViewer, {
      provide: { projectFullPath: 'path/to/project' },
      propsData: {
        blobInfo: defaultProps.blobInfo,
        filePath: defaultProps.filePath,
        branchRef: defaultProps.branchRef,
        hlInfo: defaultProps.hlInfo,
        ...props,
      },
      stubs: { GlSprintf },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findVulFileContentViewer = () => wrapper.findComponent(VulnerabilityFileContentViewer);
  const findBlobHeader = () => wrapper.findComponent(BlobHeader);
  const findGlAlert = () => wrapper.findComponent(GlAlert);

  describe('loading and error states', () => {
    it('shows a warning if the file was not found', () => {
      createWrapper({ blobInfo: {} });

      expect(findGlAlert().text()).toBe(
        `${defaultProps.filePath} was not found in commit ${defaultProps.branchRef}`,
      );
    });

    it('displays an error alert when blobInfo is empty', () => {
      createWrapper({ blobInfo: {} });
      expect(findGlAlert().exists()).toBe(true);
    });
  });

  describe('file contents loaded', () => {
    it('shows the source code without markdown', () => {
      createWrapper();
      expect(findBlobHeader().exists()).toBe(true);
      expect(findButton().exists()).toBe(true);
      expect(findVulFileContentViewer().exists()).toBe(false);
    });

    it('shows the source code with markdown', () => {
      createWrapper({ hlInfo });
      expect(findVulFileContentViewer().exists()).toBe(true);
      expect(findVulFileContentViewer().props()).toMatchObject({
        startLine: hlInfo[0].blockStartLine,
        endLine: hlInfo[0].blockEndLine,
        isHighlighted: false,
        content: blobData.rawTextBlob,
        highlightInfo: hlInfo[0].highlightInfo,
      });
    });

    it('renders GlButton with correct aria-label when file is expanded', () => {
      createWrapper();
      expect(findButton().attributes('aria-label')).toBe('Hide file contents');
    });
  });
});
