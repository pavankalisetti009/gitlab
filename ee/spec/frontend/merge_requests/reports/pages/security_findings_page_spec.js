import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SmartInterval from '~/smart_interval';
import SecurityFindingsPage from 'ee/merge_requests/reports/pages/security_findings_page.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  createEnabledScansQueryResponse,
  mockFindingReportsComparerSuccessResponse,
  mockFindingReportsComparerParsingResponse,
  mockFindingReportsComparerEmptyResponse,
  createMockFindingReportsComparerResponse,
} from 'ee_jest/vue_merge_request_widget/mock_data';

jest.mock('~/smart_interval');

Vue.use(VueApollo);

describe('Security findings page component', () => {
  let wrapper;

  const DEFAULT_MR_PROPS = {
    targetProjectFullPath: 'gitlab-org/gitlab',
    iid: 456,
    isPipelineActive: false,
    pipeline: {
      iid: 123,
    },
  };

  const createComponent = ({ mr = {}, enabledScansHandler, findingReportsHandler } = {}) => {
    const mockApollo = createMockApollo([
      [
        enabledScansQuery,
        enabledScansHandler || jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
      ],
      [
        findingReportsComparerQuery,
        findingReportsHandler ||
          jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
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
  const findSummaryText = () => wrapper.findComponent(SummaryText);

  describe('rendering', () => {
    it('does not render when enabledScans is loading', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
      });

      expect(findSecurityFindingsPage().exists()).toBe(false);

      await waitForPromises();

      expect(findSecurityFindingsPage().exists()).toBe(true);
    });

    it('does not render when pipeline is active', async () => {
      createComponent({
        mr: { isPipelineActive: true },
        enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
      });

      await waitForPromises();

      expect(findSecurityFindingsPage().exists()).toBe(false);
    });

    it('does not render when no scans are enabled', async () => {
      createComponent({
        enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
      });

      await waitForPromises();

      expect(findSecurityFindingsPage().exists()).toBe(false);
    });

    it('renders when scans are ready, pipeline inactive, and scans enabled', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
      });

      await waitForPromises();

      expect(findSecurityFindingsPage().exists()).toBe(true);
    });
  });

  describe('SummaryText', () => {
    it('passes isLoading true while fetching reports', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler: jest.fn(() => new Promise(() => {})),
      });

      await waitForPromises();

      expect(findSummaryText().props('isLoading')).toBe(true);
    });

    it('passes isLoading false after reports are fetched', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler: jest
          .fn()
          .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
      });

      await waitForPromises();

      expect(findSummaryText().props('isLoading')).toBe(false);
    });

    it('passes totalNewVulnerabilities from reports', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler: jest
          .fn()
          .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
      });

      await waitForPromises();

      expect(findSummaryText().props('totalNewVulnerabilities')).toBe(1);
    });

    it('sums vulnerabilities from multiple reports', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true, dast: true } })),
        findingReportsHandler: jest
          .fn()
          .mockResolvedValue(mockFindingReportsComparerSuccessResponse),
      });

      await waitForPromises();

      expect(findSummaryText().props('totalNewVulnerabilities')).toBe(2);
    });

    it('passes zero vulnerabilities when scans are enabled but have no findings', async () => {
      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler: jest.fn().mockResolvedValue(mockFindingReportsComparerEmptyResponse),
      });

      await waitForPromises();

      expect(findSummaryText().props('totalNewVulnerabilities')).toBe(0);
    });

    it('passes showAtLeastHint true when a report has 25 findings', async () => {
      const findings = Array(25)
        .fill(null)
        .map((_, i) => ({
          title: `Finding ${i}`,
          uuid: `uuid-${i}`,
          severity: 'HIGH',
          state: 'DETECTED',
          foundByPipelineIid: '4',
          aiResolutionEnabled: true,
          matchesAutoDismissPolicy: false,
          __typename: 'ComparedSecurityReportFinding',
        }));

      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler: jest
          .fn()
          .mockResolvedValue(
            createMockFindingReportsComparerResponse('SAST', { added: findings, fixed: [] }),
          ),
      });

      await waitForPromises();

      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
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

  describe('finding reports', () => {
    it('fetches finding reports when scans are ready and enabled', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(findingReportsHandler).toHaveBeenCalledWith({
        fullPath: DEFAULT_MR_PROPS.targetProjectFullPath,
        iid: String(DEFAULT_MR_PROPS.iid),
        reportType: 'SAST',
        scanMode: 'FULL',
      });
    });

    it('does not fetch finding reports when no scans are enabled', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest.fn().mockResolvedValue(createEnabledScansQueryResponse()),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(findingReportsHandler).not.toHaveBeenCalled();
    });

    it('does not fetch finding reports while enabledScans is still polling', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest.fn().mockResolvedValue(
          createEnabledScansQueryResponse({
            full: { ready: false, sast: true },
            partial: { ready: false },
          }),
        ),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(SmartInterval).toHaveBeenCalled();
      expect(findingReportsHandler).not.toHaveBeenCalled();
    });

    it('fetches reports for multiple scan types', async () => {
      const findingReportsHandler = jest
        .fn()
        .mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        enabledScansHandler: jest
          .fn()
          .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true, dast: true } })),
        findingReportsHandler,
      });

      await waitForPromises();

      expect(findingReportsHandler).toHaveBeenCalledTimes(2);
      expect(findingReportsHandler).toHaveBeenCalledWith(
        expect.objectContaining({ reportType: 'SAST' }),
      );
      expect(findingReportsHandler).toHaveBeenCalledWith(
        expect.objectContaining({ reportType: 'DAST' }),
      );
    });

    describe('polling', () => {
      it('starts polling when report status is PARSING', async () => {
        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerParsingResponse),
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalledWith(
          expect.objectContaining({
            callback: expect.any(Function),
            startingInterval: 3000,
            maxInterval: 30000,
            incrementByFactorOf: 1.5,
            immediateExecution: false,
          }),
        );
      });

      it('stops polling when report status becomes PARSED', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        const findingReportsHandler = jest
          .fn()
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse)
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse);

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler,
        });

        await waitForPromises();

        expect(SmartInterval).toHaveBeenCalled();

        const pollerCallback = SmartInterval.mock.calls[0][0].callback;
        await pollerCallback();
        await waitForPromises();

        expect(destroy).toHaveBeenCalled();
      });

      it('cleans up report pollers on destroy', async () => {
        const destroy = jest.fn();
        SmartInterval.mockImplementation(() => ({ destroy }));

        createComponent({
          enabledScansHandler: jest
            .fn()
            .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          findingReportsHandler: jest
            .fn()
            .mockResolvedValue(mockFindingReportsComparerParsingResponse),
        });

        await waitForPromises();

        wrapper.destroy();

        expect(destroy).toHaveBeenCalled();
      });
    });
  });
});
