import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import MRSecurityWidget from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import SummaryText, {
  MAX_NEW_VULNERABILITIES,
} from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SmartInterval from '~/smart_interval';
import { historyPushState } from '~/lib/utils/common_utils';
import api from '~/api';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  mockFindingReportsComparerSuccessResponse,
  mockFindingReportsComparerSuccessResponseWithFixed,
  mockFindingReportsComparerParsingResponse,
  createMockFindingReportsComparerResponse,
  createEnabledScansQueryResponse,
  createMockFinding,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({
  render: () => {},
}));
jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  historyPushState: jest.fn(),
}));
jest.mock('~/smart_interval');

describe('MR Widget Security Reports', () => {
  let wrapper;
  let findingReportsComparerHandler;

  const securityConfigurationPath = '/help/user/application_security/_index.md';
  const sourceProjectFullPath = 'namespace/project';
  const sourceBranch = 'feature-branch';

  const sastHelp = '/help/user/application_security/sast/_index';
  const dastHelp = '/help/user/application_security/dast/_index';
  const coverageFuzzingHelp = '/help/user/application_security/coverage-fuzzing/index';
  const secretDetectionHelp = '/help/user/application_security/secret-detection/index';
  const apiFuzzingHelp = '/help/user/application_security/api-fuzzing/index';
  const dependencyScanningHelp = '/help/user/application_security/api-fuzzing/index';
  const containerScanningHelp = '/help/user/application_security/container-scanning/index';

  const defaultMrPropsData = {
    targetProjectFullPath: 'gitlab-org/gitlab',
    iid: 456,
    pipeline: {
      path: '/path/to/pipeline',
      iid: 123,
    },
    enabledReports: {
      sast: true,
      dast: true,
      dependencyScanning: true,
      containerScanning: true,
      coverageFuzzing: true,
      apiFuzzing: true,
      secretDetection: true,
    },
    securityConfigurationPath,
    sourceBranch,
    sourceProjectFullPath,
    sastHelp,
    dastHelp,
    containerScanningHelp,
    dependencyScanningHelp,
    coverageFuzzingHelp,
    secretDetectionHelp,
    apiFuzzingHelp,
  };

  const defaultMockApollo = createMockApollo([
    [
      enabledScansQuery,
      jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
    ],
    [
      findingReportsComparerQuery,
      jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
    ],
  ]);

  const createComponent = ({
    propsData,
    provide,
    mountFn = shallowMountExtended,
    mockApolloProvider,
    ...options
  } = {}) => {
    wrapper = mountFn(MRSecurityWidget, {
      apolloProvider: mockApolloProvider || createMockApollo(),
      provide: {
        glFeatures: { mrSecurityWidgetGraphql: true },
        ...provide,
      },
      propsData: {
        ...propsData,
        mr: {
          ...defaultMrPropsData,
          ...propsData?.mr,
        },
      },
      stubs: {
        VulnerabilityFindingModal: stubComponent(VulnerabilityFindingModal),
      },
      ...options,
    });
  };

  const createComponentWithMockData = (mockResponse) => {
    findingReportsComparerHandler = jest.fn().mockResolvedValue(mockResponse);

    createComponent({
      mountFn: mountExtended,
      apolloProvider: createMockApollo([
        [
          enabledScansQuery,
          jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
        ],
        [findingReportsComparerQuery, findingReportsComparerHandler],
      ]),
    });

    return waitForPromises();
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findWidgetRow = () => wrapper.findComponent(ReportDetails);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findReportSummaryText = (at) => wrapper.findAllComponents(SummaryText).at(at);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findComponent(GlBadge);
  const findStandaloneModal = () => wrapper.findByTestId('vulnerability-finding-modal');

  const getFirstScanResult = () => {
    const fetchFunctions = findWidget().props('fetchCollapsedData')();
    return fetchFunctions[0]();
  };

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
  });

  describe('with active pipeline', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: true } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with no enabled reports', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: false, enabledReports: {} } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with only clusterImageScanning enabled', () => {
    beforeEach(async () => {
      const onlyClusterImageScanningEnabled = {
        sast: false,
        dast: false,
        dependencyScanning: false,
        containerScanning: false,
        coverageFuzzing: false,
        apiFuzzing: false,
        secretDetection: false,
        clusterImageScanning: true,
      };
      createComponent({
        propsData: { mr: { isPipelineActive: false, enabledReports: {} } },
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: { ...onlyClusterImageScanningEnabled },
                partial: { ...onlyClusterImageScanningEnabled },
              }),
            ),
          ],
        ]),
      });
      await waitForPromises();
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with empty MR data', () => {
    beforeEach(async () => {
      createComponent({ mockApolloProvider: defaultMockApollo });
      await waitForPromises();
    });

    it('should mount the widget component', () => {
      expect(findWidget().props()).toMatchObject({
        statusIconName: 'success',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: expect.any(Function),
        multiPolling: true,
      });
    });

    it('handles loading state', async () => {
      expect(findSummaryText().props()).toMatchObject({ isLoading: true });
      findWidget().vm.$emit('is-loading', false);
      await nextTick();
      expect(findSummaryText().props()).toMatchObject({ isLoading: false });
    });

    it('does not display the summary highlights component', () => {
      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('should not be collapsible', () => {
      expect(findWidget().props('isCollapsible')).toBe(false);
    });
  });

  describe('with MR data', () => {
    const expandWidget = async () => {
      // Click on the toggle button to expand data
      wrapper.findByRole('button', { name: 'Show details' }).trigger('click');
      await nextTick();

      // Second next tick is for the dynamic scroller
      await nextTick();
    };

    it('should make a call only for enabled reports', async () => {
      const handler = jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse);

      createComponent({
        mountFn: mountExtended,
        propsData: {
          mr: {
            enabledReports: {
              sast: true,
              dast: true,
            },
          },
        },
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      expect(handler).toHaveBeenCalledTimes(2);
      expect(handler).toHaveBeenCalledWith({
        fullPath: defaultMrPropsData.targetProjectFullPath,
        iid: String(defaultMrPropsData.iid),
        reportType: 'SAST',
        scanMode: 'FULL',
      });
      expect(handler).toHaveBeenCalledWith({
        fullPath: defaultMrPropsData.targetProjectFullPath,
        iid: String(defaultMrPropsData.iid),
        reportType: 'DAST',
        scanMode: 'FULL',
      });
    });

    it('should display the view all pipeline findings button', async () => {
      await createComponent({ mockApolloProvider: defaultMockApollo });

      expect(findWidget().props('actionButtons')).toEqual([
        {
          href: '/path/to/pipeline/security',
          text: 'View all pipeline findings',
          trackFullReportClicked: true,
        },
      ]);
    });

    it('should mount the widget component', async () => {
      const handler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [createMockFinding(), createMockFinding()],
          fixed: [createMockFinding(), createMockFinding()],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      expect(findWidget().props()).toMatchObject({
        statusIconName: 'warning',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: wrapper.vm.fetchCollapsedData,
        multiPolling: true,
      });
    });

    it('computes the total number of new potential vulnerabilities correctly', async () => {
      const sastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [
            createMockFinding({ severity: 'CRITICAL' }),
            createMockFinding({ severity: 'HIGH' }),
          ],
          fixed: [createMockFinding(), createMockFinding()],
        }),
      );

      const dastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('DAST', {
          added: [
            createMockFinding({ severity: 'LOW' }),
            createMockFinding({ severity: 'UNKNOWN' }),
          ],
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn((variables) => {
              if (variables.reportType === 'SAST') return sastHandler(variables);
              if (variables.reportType === 'DAST') return dastHandler(variables);
              return Promise.resolve(mockFindingReportsComparerSuccessResponse);
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
      expect(findSummaryHighlights().props()).toMatchObject({
        highlights: { critical: 1, high: 1, other: 2 },
      });
    });

    it('tells the widget to be collapsible only if there is data', async () => {
      const handler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [createMockFinding()],
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: { sast: true },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      expect(findWidget().props('isCollapsible')).toBe(false);
      await waitForPromises();
      expect(findWidget().props('isCollapsible')).toBe(true);
    });

    it('tells summary-text to display a ui hint when there are 25 findings in a single report', async () => {
      const sastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [...Array(MAX_NEW_VULNERABILITIES)].map((_, i) =>
            createMockFinding({ uuid: `${i}4abc` }),
          ),
          fixed: [],
        }),
      );

      const dastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('DAST', {
          added: [...Array(10)].map((_, i) => createMockFinding({ uuid: `${i}3abc` })),
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn((variables) => {
              if (variables.reportType === 'SAST') return sastHandler(variables);
              if (variables.reportType === 'DAST') return dastHandler(variables);
              return Promise.resolve(mockFindingReportsComparerSuccessResponse);
            }),
          ],
        ]),
      });

      await waitForPromises();

      await expandWidget();

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });

    it('tells summary-text NOT to display a ui hint when there are less 25 findings', async () => {
      const belowThreshold = MAX_NEW_VULNERABILITIES - 1;
      const sastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [...Array(belowThreshold)].map((_, i) => createMockFinding({ uuid: `${i}4abc` })),
          fixed: [],
        }),
      );

      const dastHandler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('DAST', {
          added: [...Array(10)].map((_, i) => createMockFinding({ uuid: `${i}3abc` })),
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn((variables) => {
              if (variables.reportType === 'SAST') return sastHandler(variables);
              if (variables.reportType === 'DAST') return dastHandler(variables);
              return Promise.resolve(mockFindingReportsComparerSuccessResponse);
            }),
          ],
        ]),
      });

      await waitForPromises();

      await expandWidget();

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(false);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });
  });

  describe('successful response', () => {
    it.each`
      type       | mockResponse
      ${'added'} | ${mockFindingReportsComparerSuccessResponse}
      ${'fixed'} | ${mockFindingReportsComparerSuccessResponseWithFixed}
    `(
      'clones "$type" GraphQL findings to make them mutable for UI state changes',
      async ({ type, mockResponse }) => {
        await createComponentWithMockData(mockResponse);
        const result = await getFirstScanResult();

        const originalFinding =
          mockResponse.data.project.mergeRequest.findingReportsComparer.report[type][0];

        expect(result.data[type][0]).not.toBe(originalFinding);
        expect(result.data[type][0]).toEqual(originalFinding);
      },
    );
  });

  describe('error handling', () => {
    const createComponentWithError = async () => {
      const graphqlError = {
        graphQLErrors: [
          {
            extensions: { code: 'PARSING_ERROR' },
            message: 'Schema parsing failed',
          },
        ],
      };

      const customHandler = jest.fn().mockRejectedValue(graphqlError);

      createComponent({
        mountFn: mountExtended,
        apolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          ],
          [findingReportsComparerQuery, customHandler],
        ]),
      });
      await waitForPromises();
    };

    it('handles GraphQL errors', async () => {
      await createComponentWithError();

      const result = await getFirstScanResult();
      expect(result.status).toBe(500);
      expect(result.data.error).toBe(true);
    });

    it('displays parsing error message in DOM', async () => {
      await createComponentWithError();
      await getFirstScanResult(); // Trigger the error

      expect(
        wrapper
          .findByText('Parsing schema failed. Check the validity of your .gitlab-ci.yml content.')
          .exists(),
      ).toBe(true);
    });
  });

  describe('polling behaviour', () => {
    const expectProcessingResult = (result) => {
      expect(result.status).toBe(202);
      expect(result.headers).toEqual({ 'poll-interval': 3000 });
      return result;
    };

    const expectParsedResult = (result) => {
      expect(result.status).toBe(200);
      expect(result.headers).toEqual({});
      expect(result.data.status).toBe('PARSED');
      return result;
    };

    describe('when status is PARSED', () => {
      beforeEach(async () => {
        await createComponentWithMockData(mockFindingReportsComparerSuccessResponse);
      });

      it('returns parsed data without polling headers', async () => {
        const result = await getFirstScanResult();

        expectParsedResult(result);
        expect(result.headers['poll-interval']).toBeUndefined();
      });
    });

    describe('when status is PROCESSING', () => {
      beforeEach(async () => {
        await createComponentWithMockData(mockFindingReportsComparerParsingResponse);
      });

      it('returns polling headers with 3 second interval', async () => {
        const result = await getFirstScanResult();

        expectProcessingResult(result);
      });
    });

    describe('polling sequence', () => {
      it('makes multiple requests when polling until PARSED', async () => {
        const customFindingReportsHandler = jest.fn();
        customFindingReportsHandler
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse) // Component setup
          .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse) // 1st poll - PROCESSING
          .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse); // 2nd poll - PARSED

        createComponent({
          mountFn: mountExtended,
          apolloProvider: createMockApollo([
            [
              enabledScansQuery,
              jest
                .fn()
                .mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
            ],
            [findingReportsComparerQuery, customFindingReportsHandler],
          ]),
        });

        await waitForPromises();

        // 1st poll - returns PROCESSING
        let result = await getFirstScanResult();
        expectProcessingResult(result);

        // 2nd poll - returns PARSED
        result = await getFirstScanResult();
        expectParsedResult(result);

        expect(customFindingReportsHandler).toHaveBeenCalledTimes(3);
      });
    });
  });

  describe('modal', () => {
    const createComponentAndExpandWidget = async (options = {}) => {
      const handler = jest.fn().mockResolvedValue(
        createMockFindingReportsComparerResponse('SAST', {
          added: [createMockFinding({ state: options.state || 'DETECTED' })],
          fixed: [],
        }),
      );

      createComponent({
        mountFn: mountExtended,
        propsData: options.propsData,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              createEnabledScansQueryResponse({
                full: { sast: true },
              }),
            ),
          ],
          [findingReportsComparerQuery, handler],
        ]),
      });

      await waitForPromises();

      // Click on the toggle button to expand data
      wrapper.findByRole('button', { name: 'Show details' }).trigger('click');
      await nextTick();
      await nextTick(); // Second next tick is for the dynamic scroller

      return wrapper.vm.reportsByScanType.full.SAST.added[0];
    };

    it('does not display the modal until the finding is clicked', async () => {
      await createComponentAndExpandWidget();
      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('clears modal data when the modal is closed', async () => {
      const transformedFinding = await createComponentAndExpandWidget();

      findWidgetRow().vm.$emit('modal-data', transformedFinding);
      await nextTick();

      expect(findStandaloneModal().props('modal')).not.toBe(null);

      findStandaloneModal().vm.$emit('hidden');
      await nextTick();

      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('renders the modal when the finding is clicked', async () => {
      const targetProjectFullPath = 'root/security-reports-v2';
      const transformedFinding = await createComponentAndExpandWidget({
        propsData: { mr: { targetProjectFullPath } },
      });

      findWidgetRow().vm.$emit('modal-data', transformedFinding);
      await nextTick();

      const modal = findStandaloneModal();

      expect(modal.props()).toMatchObject({
        findingUuid: '1',
        pipelineIid: 123,
        projectFullPath: targetProjectFullPath,
        sourceProjectFullPath,
        branchRef: sourceBranch,
      });
    });

    describe('resolve with AI', () => {
      jest.useFakeTimers();
      useMockLocationHelper();

      const aiCommentUrl = `${TEST_HOST}/project/merge_requests/2#note_1`;
      const addCommentToDOM = () => {
        const comment = document.createElement('div');
        comment.id = 'note_1';
        document.body.appendChild(comment);

        return nextTick();
      };

      beforeEach(async () => {
        const transformedFinding = await createComponentAndExpandWidget();
        findWidgetRow().vm.$emit('modal-data', transformedFinding);
        await nextTick();
      });

      afterEach(() => {
        // remove the comment from the DOM
        document.getElementById('note_1')?.remove();
      });

      it('scrolls to the comment when the comment note that is added by the AI-action is already on the page', async () => {
        expect(window.location.assign).not.toHaveBeenCalled();
        expect(findStandaloneModal().exists()).toBe(true);

        findStandaloneModal().vm.$emit('resolveWithAiSuccess', aiCommentUrl);

        await addCommentToDOM();

        expect(window.location.assign).toHaveBeenCalledWith(aiCommentUrl);
        expect(window.location.reload).not.toHaveBeenCalled();

        await nextTick();

        expect(findStandaloneModal().exists()).toBe(false);
      });

      it('scrolls to the comment when the comment note that is added by the AI-action is on the page', async () => {
        expect(window.location.assign).not.toHaveBeenCalled();
        expect(findStandaloneModal().exists()).toBe(true);

        findStandaloneModal().vm.$emit('resolveWithAiSuccess', aiCommentUrl);

        // at this point the comment is not yet within the DOM
        expect(window.location.assign).not.toHaveBeenCalledWith(aiCommentUrl);

        await addCommentToDOM();

        expect(window.location.assign).toHaveBeenCalledWith(aiCommentUrl);
        expect(window.location.reload).not.toHaveBeenCalled();

        await nextTick();

        expect(findStandaloneModal().exists()).toBe(false);
      });

      it('does a hard-reload when the comment note that is added by the AI-action is not on the page within 3 seconds', async () => {
        expect(window.location.reload).not.toHaveBeenCalled();

        findStandaloneModal().vm.$emit('resolveWithAiSuccess', aiCommentUrl);
        await nextTick();

        jest.advanceTimersByTime(3000);

        expect(historyPushState).toHaveBeenCalledWith(aiCommentUrl);
        expect(window.location.reload).toHaveBeenCalled();
      });
    });

    describe('dismissed badge', () => {
      it('renders the dismissed badge when `dismissed` is emitted', async () => {
        const transformedFinding = await createComponentAndExpandWidget();

        findWidgetRow().vm.$emit('modal-data', transformedFinding);
        await nextTick();

        expect(findDismissedBadge().exists()).toBe(false);

        findStandaloneModal().vm.$emit('dismissed');
        await nextTick();

        expect(transformedFinding.state).toBe('dismissed');
      });

      it('does not render the dismissed badge when `detected` is emitted', async () => {
        const transformedFinding = await createComponentAndExpandWidget({ state: 'DISMISSED' });

        findWidgetRow().vm.$emit('modal-data', transformedFinding);
        await nextTick();

        expect(findDismissedBadge().exists()).toBe(true);

        findStandaloneModal().vm.$emit('detected');
        await nextTick();

        expect(transformedFinding.state).toBe('detected');
      });
    });
  });

  describe('partial scans', () => {
    it('displays loading state until enabled scans are fetched', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(createEnabledScansQueryResponse({ full: { sast: true } })),
          ],
        ]),
      });

      const loadingText = 'Security scanning is loading';
      expect(findWidget().text()).toBe(loadingText);

      await waitForPromises();
      expect(findWidget().text()).not.toBe(loadingText);
    });

    it.each`
      fullScans | partialScans | expectedScanModes
      ${false}  | ${false}     | ${[]}
      ${true}   | ${false}     | ${['FULL']}
      ${false}  | ${true}      | ${['PARTIAL']}
      ${true}   | ${true}      | ${['FULL', 'PARTIAL']}
    `(
      'should fetch full scans=$fullScans, partial scans=$partialScans',
      async ({ fullScans, partialScans, expectedScanModes }) => {
        const handler = jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse);

        createComponent({
          mountFn: mountExtended,
          propsData: {
            mr: {
              enabledReports: {
                sast: true,
              },
            },
          },
          mockApolloProvider: createMockApollo([
            [
              enabledScansQuery,
              jest.fn().mockResolvedValue(
                createEnabledScansQueryResponse({
                  full: { sast: fullScans },
                  partial: { sast: partialScans },
                }),
              ),
            ],
            [findingReportsComparerQuery, handler],
          ]),
        });

        await waitForPromises();

        expect(handler).toHaveBeenCalledTimes(expectedScanModes.length);

        expectedScanModes.forEach((scanMode) => {
          expect(handler).toHaveBeenCalledWith({
            fullPath: defaultMrPropsData.targetProjectFullPath,
            iid: String(defaultMrPropsData.iid),
            reportType: 'SAST',
            scanMode,
          });
        });
      },
    );

    it('should refetch the query if scan is not ready', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest
              .fn()
              .mockResolvedValueOnce(
                createEnabledScansQueryResponse({
                  full: { ready: false },
                  partial: { ready: false },
                }),
              )
              .mockResolvedValueOnce(
                createEnabledScansQueryResponse({
                  full: { ready: true },
                  partial: { ready: true },
                }),
              ),
          ],
          [
            findingReportsComparerQuery,
            jest.fn().mockResolvedValue(mockFindingReportsComparerSuccessResponse),
          ],
        ]),
      });

      await waitForPromises();

      expect(SmartInterval).toHaveBeenCalledWith(
        expect.objectContaining({
          callback: expect.any(Function),
          incrementByFactorOf: 1,
          startingInterval: 3000,
          immediateExecution: true,
        }),
      );

      // Widget should be loading
      expect(findWidget().text()).toBe('Security scanning is loading');

      const spy = jest.spyOn(wrapper.vm.$options.pollingInterval, 'destroy');

      wrapper.vm.$apollo.queries.enabledScans.refetch();

      await waitForPromises();

      expect(spy).toHaveBeenCalledTimes(1);
    });

    it('when the query fails', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockRejectedValue({
              data: {},
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(
        wrapper.findByText('Error while fetching enabled scans. Please try again later.').exists(),
      ).toBe(true);
    });

    it('when the pipeline is null, it should not render anything', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValueOnce({
              data: {
                project: {
                  id: 'gid://1',
                  pipeline: null,
                },
              },
            }),
          ],
        ]),
      });

      await waitForPromises();

      expect(wrapper.text()).toBe('');
    });
  });
});
