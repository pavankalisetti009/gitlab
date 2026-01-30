import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SmartInterval from '~/smart_interval';
import SecurityFindingsPage from 'ee/merge_requests/reports/pages/security_findings_page.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import { createEnabledScansQueryResponse } from 'ee_jest/vue_merge_request_widget/mock_data';

jest.mock('~/smart_interval');

Vue.use(VueApollo);

describe('Security findings page component', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    targetProjectFullPath: 'gitlab-org/gitlab',
    pipeline: {
      iid: 123,
    },
  };

  const createComponent = ({ mr = {}, enabledScansHandler } = {}) => {
    const mockApollo = createMockApollo([
      [
        enabledScansQuery,
        enabledScansHandler || jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
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
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ enabledScansHandler });

      expect(enabledScansHandler).toHaveBeenCalledWith({
        fullPath: targetProjectFullPath,
        pipelineIid: pipeline.iid,
      });
    });

    it('skips query when pipelineIid is missing', () => {
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { pipeline: null }, enabledScansHandler });

      expect(enabledScansHandler).not.toHaveBeenCalled();
    });

    it('skips query when targetProjectFullPath is missing', () => {
      const enabledScansHandler = jest.fn().mockResolvedValue(createEnabledScansQueryResponse());
      createComponent({ mr: { targetProjectFullPath: null }, enabledScansHandler });

      expect(enabledScansHandler).not.toHaveBeenCalled();
    });

    describe('when query fails', () => {
      it('displays error message', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        });

        await waitForPromises();

        expect(findSecurityFindingsPage().text()).toContain(
          'Error while fetching enabled scans. Please try again later.',
        );
      });
    });

    describe('polling', () => {
      it('starts polling when scans are not ready', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(
            createEnabledScansQueryResponse({
              full: { ready: false },
              partial: { ready: false },
            }),
          ),
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalledWith(
          expect.objectContaining({
            callback: expect.any(Function),
            startingInterval: 3000,
            incrementByFactorOf: 1,
            immediateExecution: true,
          }),
        );
      });

      it('does not start polling when scans are ready', async () => {
        createComponent({
          enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        });

        await waitForPromises();

        expect(SmartInterval).not.toHaveBeenCalled();
      });

      it('stops polling when scans become ready', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        const enabledScansHandler = jest
          .fn()
          .mockResolvedValueOnce(
            createEnabledScansQueryResponse({ full: { ready: false }, partial: { ready: false } }),
          )
          .mockResolvedValueOnce(createEnabledScansQueryResponse());

        createComponent({ enabledScansHandler });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalled();

        wrapper.vm.$apollo.queries.enabledScans.refetch();
        await waitForPromises();

        expect(destroy).toHaveBeenCalled();
      });
    });
  });
});
