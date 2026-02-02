import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SecurityFindingsPage from 'ee/merge_requests/reports/pages/security_findings_page.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import { createEnabledScansQueryResponse } from 'ee_jest/vue_merge_request_widget/mock_data';

Vue.use(VueApollo);

describe('Security findings page component', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    targetProjectFullPath: 'gitlab-org/gitlab',
    pipeline: {
      iid: 123,
    },
  };

  const createComponent = ({ mr = {}, queryHandler } = {}) => {
    const mockApollo = createMockApollo([
      [
        enabledScansQuery,
        queryHandler || jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
      ],
    ]);

    wrapper = shallowMountExtended(SecurityFindingsPage, {
      apolloProvider: mockApollo,
      propsData: {
        mr: { ...DEFAULT_MR_PROPS, ...mr },
      },
    });
  };

  const findSecurityFindingsPage = () => wrapper.findByTestId('security-findings-page');

  describe('rendering', () => {
    it('renders the security findings page', () => {
      createComponent();

      expect(findSecurityFindingsPage().exists()).toBe(true);
    });
  });

  describe('enabledScans query', () => {
    it('fetches enabled scans with correct variables', () => {
      const { targetProjectFullPath, pipeline } = DEFAULT_MR_PROPS;
      const queryHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ queryHandler });

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: targetProjectFullPath,
        pipelineIid: pipeline.iid,
      });
    });

    it('skips query when pipelineIid is missing', () => {
      const queryHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { pipeline: null }, queryHandler });

      expect(queryHandler).not.toHaveBeenCalled();
    });

    it('skips query when targetProjectFullPath is missing', () => {
      const queryHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { targetProjectFullPath: null }, queryHandler });

      expect(queryHandler).not.toHaveBeenCalled();
    });

    describe('when query fails', () => {
      it('displays error message', async () => {
        createComponent({
          queryHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        });

        await waitForPromises();

        expect(findSecurityFindingsPage().text()).toContain(
          'Error while fetching enabled scans. Please try again later.',
        );
      });
    });
  });
});
