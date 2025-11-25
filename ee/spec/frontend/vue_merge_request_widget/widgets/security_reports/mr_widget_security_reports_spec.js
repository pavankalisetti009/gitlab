import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import MRSecurityWidget from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SmartInterval from '~/smart_interval';
import { historyPushState } from '~/lib/utils/common_utils';
import api from '~/api';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';
import axios from '~/lib/utils/axios_utils';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import {
  mockFindingReportsComparerSuccessResponse,
  mockFindingReportsComparerParsingResponse,
  mockFindingReportsComparerSuccessResponseWithFixed,
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
  let mockAxios;

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

  const reportEndpoints = {
    sastComparisonPathV2: '/my/sast/endpoint?type=sast',
    dastComparisonPathV2: '/my/dast/endpoint?type=dast',
    dependencyScanningComparisonPathV2: '/my/dependency-scanning/endpoint?type=dependency_scanning',
    coverageFuzzingComparisonPathV2: '/my/coverage-fuzzing/endpoint?type=coverage_fuzzing',
    apiFuzzingComparisonPathV2: '/my/api-fuzzing/endpoint?type=api_fuzzing',
    secretDetectionComparisonPathV2: '/my/secret-detection/endpoint?type=secret_deteection',
    containerScanningComparisonPathV2: '/my/container-scanning/endpoint?type=container_scanning',
  };

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
    ...reportEndpoints,
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

  const enabledScansQueryResult = (overrides = { full: {}, partial: {} }) => ({
    data: {
      project: {
        id: 2,
        pipeline: {
          id: 11,
          enabledSecurityScans: {
            ready: true,
            sast: true,
            dast: false,
            dependencyScanning: false,
            containerScanning: false,
            coverageFuzzing: false,
            apiFuzzing: false,
            secretDetection: false,
            clusterImageScanning: false,
            __typename: 'EnabledSecurityScans',
            ...overrides?.full,
          },
          enabledPartialSecurityScans: {
            ready: true,
            sast: false,
            dast: false,
            dependencyScanning: false,
            containerScanning: false,
            coverageFuzzing: false,
            apiFuzzing: false,
            secretDetection: false,
            clusterImageScanning: false,
            __typename: 'EnabledSecurityScans',
            ...overrides?.partial,
          },
        },
      },
    },
  });

  const defaultMockApollo = createMockApollo([
    [enabledScansQuery, jest.fn().mockResolvedValue(enabledScansQueryResult())],
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
      provide,
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

  const createComponentAndExpandWidget = async ({
    mockDataFn,
    mockDataProps,
    mrProps = {},
    ...options
  }) => {
    mockDataFn(mockDataProps);
    createComponent({
      mountFn: mountExtended,
      propsData: {
        mr: mrProps,
      },
      mockApolloProvider: createMockApollo([
        [
          enabledScansQuery,
          jest.fn().mockResolvedValue(
            enabledScansQueryResult({
              full: {
                sast: true,
                dast: true,
              },
            }),
          ),
        ],
      ]),
      ...options,
    });

    await waitForPromises();

    // Click on the toggle button to expand data
    wrapper.findByRole('button', { name: 'Show details' }).trigger('click');
    await nextTick();

    // Second next tick is for the dynamic scroller
    await nextTick();
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findWidgetRow = () => wrapper.findComponent(ReportDetails);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findReportSummaryText = (at) => wrapper.findAllComponents(SummaryText).at(at);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findComponent(GlBadge);
  const findStandaloneModal = () => wrapper.findByTestId('vulnerability-finding-modal');

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
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

  describe('partial scans', () => {
    it('should display a loading state until enabled scans are fetched', async () => {
      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: defaultMockApollo,
      });

      expect(findWidget().text()).toBe('Security scanning is loading');
      await waitForPromises();
      expect(findWidget().text()).not.toBe('Security scanning is loading');
    });

    it.each`
      fullScans | partialScans | expectedNumberOfRESTcalls | expectedScanModes
      ${false}  | ${false}     | ${0}                      | ${[]}
      ${true}   | ${false}     | ${1}                      | ${['full']}
      ${false}  | ${true}      | ${1}                      | ${['partial']}
      ${true}   | ${true}      | ${2}                      | ${['full', 'partial']}
    `(
      'should fetch full scans=$fullScans, partial scans=$partialScans',
      async ({ fullScans, partialScans, expectedNumberOfRESTcalls, expectedScanModes }) => {
        createComponent({
          mountFn: mountExtended,
          mockApolloProvider: createMockApollo([
            [
              enabledScansQuery,
              jest.fn().mockResolvedValue(
                enabledScansQueryResult({
                  full: {
                    sast: fullScans,
                  },
                  partial: {
                    sast: partialScans,
                  },
                }),
              ),
            ],
          ]),
        });

        await waitForPromises();

        expect(mockAxios.history.get).toHaveLength(expectedNumberOfRESTcalls);

        for (let i = 0; i < expectedNumberOfRESTcalls; i += 1) {
          expect(mockAxios.history.get[i].url).toEqual(
            reportEndpoints.sastComparisonPathV2.concat(`&scan_mode=${expectedScanModes[i]}`),
          );
        }
      },
    );

    it('should refetch the query if scan is not ready', async () => {
      // For some reason if this is not present, tests break
      mockAxios = new MockAdapter(axios);

      createComponent({
        mountFn: mountExtended,
        apolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest
              .fn()
              .mockResolvedValueOnce(
                enabledScansQueryResult({ full: { ready: false }, partial: { ready: false } }),
              )
              .mockResolvedValueOnce(
                enabledScansQueryResult({
                  full: { ready: true },
                  partial: { ready: true },
                }),
              ),
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
        apolloProvider: createMockApollo([
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
        apolloProvider: createMockApollo([
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

  describe('with empty MR data', () => {
    beforeEach(() => {
      createComponent({ mockApolloProvider: defaultMockApollo });
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
    const mockWithData = ({ findings, scanMode = 'full' } = {}) => {
      mockAxios
        .onGet(reportEndpoints.sastComparisonPathV2.concat(`&scan_mode=${scanMode}`))
        .replyOnce(
          HTTP_STATUS_OK,
          findings?.sast || {
            added: [
              {
                uuid: '1',
                severity: 'critical',
                name: 'Password leak',
                state: 'dismissed',
              },
              { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
            ],
            fixed: [
              { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
              { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
            ],
          },
        );

      mockAxios
        .onGet(reportEndpoints.dastComparisonPathV2.concat(`&scan_mode=${scanMode}`))
        .replyOnce(
          HTTP_STATUS_OK,
          findings?.dast || {
            added: [
              { uuid: '5', severity: 'low', name: 'SQL Injection' },
              { uuid: '3', severity: 'unknown', name: 'Weak password' },
            ],
          },
        );

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path.concat(`&scan_mode=${scanMode}`)).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    const createComponentWithData = async (mockWithDataProps) => {
      mockWithData(mockWithDataProps);

      createComponent({
        mountFn: mountExtended,
        mockApolloProvider: createMockApollo([
          [
            enabledScansQuery,
            jest.fn().mockResolvedValue(
              enabledScansQueryResult({
                full: {
                  sast: true,
                  dast: true,
                },
              }),
            ),
          ],
        ]),
      });

      await waitForPromises();
    };

    it('should make a call only for enabled reports', async () => {
      mockWithData();

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
      });

      await waitForPromises();

      expect(mockAxios.history.get).toHaveLength(2);
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
      await createComponentWithData();

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
      await createComponentWithData();

      expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
      expect(findSummaryHighlights().props()).toMatchObject({
        highlights: { critical: 1, high: 1, other: 2 },
      });
    });

    it('tells the widget to be collapsible only if there is data', async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
      });

      expect(findWidget().props('isCollapsible')).toBe(false);
      await waitForPromises();
      expect(findWidget().props('isCollapsible')).toBe(true);
    });

    it('tells summary-text to display a ui hint when there are 25 findings in a single report', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(25)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });

    it('tells summary-text NOT to display a ui hint when there are less 25 findings', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(24)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(false);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });
  });

  describe('error states', () => {
    const mockWithData = ({ errorCode = HTTP_STATUS_INTERNAL_SERVER_ERROR } = {}) => {
      mockAxios
        .onGet(reportEndpoints.sastComparisonPathV2.concat('&scan_mode=full'))
        .replyOnce(errorCode);

      mockAxios
        .onGet(reportEndpoints.dastComparisonPathV2.concat('&scan_mode=full'))
        .replyOnce(HTTP_STATUS_OK, {
          added: [
            { uuid: 5, severity: 'low', name: 'SQL Injection' },
            { uuid: 3, severity: 'unknown', name: 'Weak password' },
          ],
        });

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path.concat('&scan_mode=full')).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    it('displays a top level error message when there is a bad request', async () => {
      mockWithData({ errorCode: HTTP_STATUS_BAD_REQUEST });
      createComponent({ mountFn: mountExtended });

      await waitForPromises();

      expect(
        wrapper
          .findByText('Parsing schema failed. Check the validity of your .gitlab-ci.yml content.')
          .exists(),
      ).toBe(true);

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(false);
    });
  });

  describe('modal', () => {
    let mockedFindings = [];

    beforeEach(() => {
      mockedFindings = [];
    });

    const mockFinding = (props) => {
      const finding = {
        uuid: '1',
        severity: 'critical',
        name: 'Password leak',
        found_by_pipeline: {
          iid: 1,
        },
        project: {
          id: 278964,
          name: 'GitLab',
          full_path: '/gitlab-org/gitlab',
          full_name: 'GitLab.org / GitLab',
        },
        ...props,
      };

      mockedFindings.push(finding);

      return finding;
    };

    const mockWithData = (props) => {
      Object.keys(reportEndpoints).forEach((key, i) => {
        mockAxios.onGet(reportEndpoints[key].concat('&scan_mode=full')).replyOnce(HTTP_STATUS_OK, {
          added: [mockFinding({ uuid: i.toString(), ...props })],
        });
      });
    };

    const createComponentExpandWidgetAndOpenModal = async ({
      mockDataFn = mockWithData,
      mockDataProps,
      mrProps,
      ...options
    } = {}) => {
      await createComponentAndExpandWidget({
        mockDataFn,
        mockDataProps,
        mrProps,
        ...options,
      });

      // Click on the vulnerability name
      findWidgetRow().vm.$emit('modal-data', mockedFindings[0]);

      await nextTick();
    };

    const mockWithDataOneFinding = (state = 'dismissed') => {
      mockAxios
        .onGet(reportEndpoints.sastComparisonPathV2.concat('&scan_mode=full'))
        .replyOnce(HTTP_STATUS_OK, {
          added: [mockFinding({ state })],
          fixed: [],
        });

      [
        reportEndpoints.dastComparisonPathV2,
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path.concat('&scan_mode=full')).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    it('does not display the modal until the finding is clicked', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
      });

      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('clears modal data when the modal is closed', async () => {
      await createComponentExpandWidgetAndOpenModal();

      expect(findStandaloneModal().props('modal')).not.toBe(null);

      findStandaloneModal().vm.$emit('hidden');
      await nextTick();

      expect(findStandaloneModal().exists()).toBe(false);
    });

    it('renders the modal when the finding is clicked', async () => {
      const targetProjectFullPath = 'root/security-reports-v2';
      await createComponentExpandWidgetAndOpenModal({
        mrProps: { targetProjectFullPath },
      });

      const modal = findStandaloneModal();

      expect(modal.props()).toMatchObject({
        findingUuid: '0',
        pipelineIid: 1,
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
        await createComponentExpandWidgetAndOpenModal();
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

    it('renders the dismissed badge when `dismissed` is emitted', async () => {
      await createComponentExpandWidgetAndOpenModal({
        mockDataFn: mockWithDataOneFinding,
        mockDataProps: { state: 'detected' },
      });

      expect(findDismissedBadge().exists()).toBe(false);

      findStandaloneModal().vm.$emit('dismissed');
      await nextTick();

      expect(mockedFindings[0].state).toBe('dismissed');
    });

    it('does not render the dismissed badge when `detected` is emitted', async () => {
      await createComponentExpandWidgetAndOpenModal({ mockDataFn: mockWithDataOneFinding });

      expect(findDismissedBadge().exists()).toBe(true);

      findStandaloneModal().vm.$emit('detected');
      await nextTick();

      expect(mockedFindings[0].state).toBe('detected');
    });
  });

  describe('when mrSecurityWidgetGraphql FF is enabled', () => {
    let findingReportsComparerHandler;

    const createGraphQLComponent = (mockResponse) => {
      findingReportsComparerHandler = jest.fn().mockResolvedValue(mockResponse);

      createComponent({
        provide: {
          glFeatures: {
            vulnerabilityPartialScans: true,
            mrSecurityWidgetGraphql: true,
          },
        },
        mountFn: mountExtended,
        apolloProvider: createMockApollo([
          [enabledScansQuery, jest.fn().mockResolvedValue(enabledScansQueryResult())],
          [findingReportsComparerQuery, findingReportsComparerHandler],
        ]),
      });

      return waitForPromises();
    };

    const getFirstScanResult = () => {
      const fetchFunctions = findWidget().props('fetchCollapsedData')();
      return fetchFunctions[0]();
    };

    it('makes GraphQL query when component loads', async () => {
      await createGraphQLComponent(mockFindingReportsComparerSuccessResponse);

      expect(findingReportsComparerHandler).toHaveBeenCalledWith({
        fullPath: defaultMrPropsData.targetProjectFullPath,
        iid: String(defaultMrPropsData.iid),
        reportType: 'SAST',
        scanMode: 'FULL',
      });
    });

    it.each`
      type       | mockResponse                                          | expectedAdded | expectedFixed
      ${'added'} | ${mockFindingReportsComparerSuccessResponse}          | ${1}          | ${0}
      ${'fixed'} | ${mockFindingReportsComparerSuccessResponseWithFixed} | ${0}          | ${1}
    `(
      'transforms "$type" GraphQL findings to expected format',
      async ({ type, mockResponse, expectedAdded, expectedFixed }) => {
        await createGraphQLComponent(mockResponse);
        const result = await getFirstScanResult();

        const originalFinding =
          mockResponse.data.project.mergeRequest.findingReportsComparer.report[type][0];

        expect(result.data[type][0]).toEqual({
          uuid: originalFinding.uuid,
          name: originalFinding.title,
          severity: originalFinding.severity.toLowerCase(),
          state: originalFinding.state.toLowerCase(),
          found_by_pipeline: { iid: Number(originalFinding.foundByPipelineIid) },
        });

        expect(result.data.numberOfNewFindings).toBe(expectedAdded);
        expect(result.data.numberOfFixedFindings).toBe(expectedFixed);
      },
    );

    describe('polling behavior', () => {
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
          await createGraphQLComponent(mockFindingReportsComparerSuccessResponse);
        });

        it('returns parsed data without polling headers', async () => {
          const result = await getFirstScanResult();

          expectParsedResult(result);
          expect(result.headers['poll-interval']).toBeUndefined();
        });
      });

      describe('when status is PARSING', () => {
        beforeEach(async () => {
          await createGraphQLComponent(mockFindingReportsComparerParsingResponse);
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
            .mockResolvedValueOnce(mockFindingReportsComparerParsingResponse) // 1st poll: PARSING
            .mockResolvedValueOnce(mockFindingReportsComparerSuccessResponse); // 2nd poll: PARSED

          createComponent({
            provide: { glFeatures: { mrSecurityWidgetGraphql: true } },
            mountFn: mountExtended,
            apolloProvider: createMockApollo([
              [enabledScansQuery, jest.fn().mockResolvedValue(enabledScansQueryResult())],
              [findingReportsComparerQuery, customFindingReportsHandler],
            ]),
          });

          await waitForPromises();

          // 1st poll - returns PARSING
          let result = await getFirstScanResult();
          expectProcessingResult(result);

          // 2nd poll - returns PARSED
          result = await getFirstScanResult();
          expectParsedResult(result);

          expect(customFindingReportsHandler).toHaveBeenCalledTimes(3);
        });
      });
    });

    describe('error handling', () => {
      it('handles GraphQL errors', async () => {
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
          provide: { glFeatures: { mrSecurityWidgetGraphql: true } },
          mountFn: mountExtended,
          apolloProvider: createMockApollo([
            [enabledScansQuery, jest.fn().mockResolvedValue(enabledScansQueryResult())],
            [findingReportsComparerQuery, customHandler],
          ]),
        });

        await waitForPromises();

        const result = await getFirstScanResult();
        expect(result.status).toBe(500);
        expect(result.data.error).toBe(true);
      });

      it('displays parsing error message in DOM', async () => {
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
          provide: { glFeatures: { mrSecurityWidgetGraphql: true } },
          mountFn: mountExtended,
          apolloProvider: createMockApollo([
            [enabledScansQuery, jest.fn().mockResolvedValue(enabledScansQueryResult())],
            [findingReportsComparerQuery, customHandler],
          ]),
        });

        await waitForPromises();
        await getFirstScanResult(); // Trigger the error

        expect(
          wrapper
            .findByText('Parsing schema failed. Check the validity of your .gitlab-ci.yml content.')
            .exists(),
        ).toBe(true);
      });
    });
  });
});
