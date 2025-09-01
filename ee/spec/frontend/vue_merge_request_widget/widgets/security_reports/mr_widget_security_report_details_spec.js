import { nextTick } from 'vue';
import { GlBadge } from '@gitlab/ui';

import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import api from '~/api';

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({
  render: () => {},
}));
jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  historyPushState: jest.fn(),
}));

describe('MR Widget Security Reports - Finding', () => {
  let wrapper;

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

  const createComponent = ({ propsData, provide, mountFn = mountExtended, ...options } = {}) => {
    wrapper = mountFn(ReportDetails, {
      provide,
      propsData: {
        ...propsData,
        widgetName: 'WidgetSecurityReports',
        mr: {
          targetProjectFullPath: 'gitlab-org/gitlab',
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
          ...propsData?.mr,
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
        },
      },
      ...options,
    });
  };

  const mockReport = ({
    error,
    reportType = 'SAST',
    reportTypeDescription,
    findings = [],
    numberOfNewFindings = findings.length,
  } = {}) => {
    return {
      reportType,
      reportTypeDescription: reportTypeDescription || `${reportType.toUpperCase()}`,
      numberOfNewFindings,
      numberOfFixedFindings: findings.length - (numberOfNewFindings || 0),
      testId: `${reportType.toLowerCase()}-scan-report`,
      findings,
      added: findings.slice(0, numberOfNewFindings),
      fixed: findings.slice(numberOfNewFindings),
      error,
    };
  };

  const createComponentWithData = async ({
    reportType,
    findings,
    numberOfNewFindings,
    numberOfFixedFindings,
  } = {}) => {
    createComponent({
      propsData: {
        report: mockReport({
          reportType,
          numberOfNewFindings,
          numberOfFixedFindings,
          findings: findings || [
            {
              uuid: '1',
              severity: 'critical',
              name: 'Password leak',
              state: 'dismissed',
            },
            { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
            { uuid: '14abc', severity: 'medium', name: 'SQL vulnerability' },
            { uuid: 'bc41e', severity: 'low', name: 'SQL vulnerability 2' },
          ],
        }),
      },
    });

    await nextTick();
  };

  const findMrWidgetRow = () => wrapper.findComponent(MrWidgetRow);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findComponent(GlBadge);
  const findDynamicScroller = () => wrapper.findByTestId('dynamic-content-scroller');

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
  });

  it('should display the dismissed badge', async () => {
    createComponentWithData();

    // This is for the dynamic scroller
    await nextTick();

    // Needed for Vue 3 specs
    await nextTick();

    expect(findDismissedBadge().text()).toBe('Dismissed');
  });

  describe('resolve with AI badge', () => {
    const findingUuid = '1';
    const findAiResolvableBadge = () => wrapper.findByTestId('ai-resolvable-badge');
    const findAiResolvableBadgePopover = () =>
      wrapper.findByTestId(`ai-resolvable-badge-popover-${findingUuid}`);

    describe.each`
      resolveVulnerabilityWithAi | aiResolutionEnabled
      ${false}                   | ${true}
      ${true}                    | ${false}
    `(
      'with "resolveVulnerabilityWithAi" ability set to "$resolveVulnerabilityWithAi" and the vulnerability has "ai_resolution_enabled" set to: "$aiResolutionEnabled"',
      ({ resolveVulnerabilityWithAi, aiResolutionEnabled }) => {
        beforeEach(() =>
          createComponent({
            propsData: {
              report: mockReport({
                numberOfNewFindings: 1,
                findings: [
                  {
                    uuid: findingUuid,
                    severity: 'critical',
                    name: 'Password leak',
                    state: 'dismissed',
                    ai_resolution_enabled: aiResolutionEnabled,
                  },
                ],
              }),
            },
            provide: {
              glAbilities: {
                resolveVulnerabilityWithAi,
              },
            },
          }),
        );

        it('should not show the AI-Badge', () => {
          expect(findAiResolvableBadge().exists()).toBe(false);
        });

        it('should not show the AI-Badge popover', () => {
          expect(findAiResolvableBadgePopover().exists()).toBe(false);
        });
      },
    );

    describe('with "resolveVulnerabilityWithAi" ability set to "true" and the vulnerability has "ai_resolution_enabled" set to: "true"', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            glAbilities: {
              resolveVulnerabilityWithAi: true,
            },
          },
          propsData: {
            report: mockReport({
              numberOfNewFindings: 1,
              findings: [
                {
                  uuid: findingUuid,
                  severity: 'critical',
                  name: 'Password leak',
                  state: 'dismissed',
                  ai_resolution_enabled: true,
                },
              ],
            }),
          },
        });

        // Wait for the dynamic scroller
        await nextTick();
      });

      it('should show the AI-Badge', () => {
        expect(findAiResolvableBadge().exists()).toBe(true);
      });

      it('should add the correct id-attribute to the AI-Badge', () => {
        expect(findAiResolvableBadge().attributes('id')).toBe(`ai-resolvable-badge-${findingUuid}`);
      });

      it('should show a popover for the AI-Badge', () => {
        expect(findAiResolvableBadgePopover().exists()).toBe(true);
      });

      it('should pass the correct props to the AI-Badge popover', () => {
        expect(wrapper.findByTestId('ai-resolvable-badge-popover-1').props()).toMatchObject({
          target: `ai-resolvable-badge-${findingUuid}`,
          // the popover and target are within a dynamic scroller, so this needs to be set to make it work correctly
          boundary: 'viewport',
        });
      });
    });
  });

  it('computes the total number of new potential vulnerabilities correctly', async () => {
    await createComponentWithData();

    expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
    expect(findSummaryHighlights().props()).toMatchObject({
      highlights: { critical: 1, high: 1, other: 2 },
    });
  });

  it('displays detailed data', async () => {
    await createComponentWithData();

    expect(wrapper.findByText(/XSS vulnerability/).exists()).toBe(true);
    expect(wrapper.findByText(/Password leak/).exists()).toBe(true);
    expect(wrapper.findByTestId('sast-scan-report').text()).toBe(
      'SAST detected 4 new potential vulnerabilities',
    );
  });

  it('contains new and fixed findings in the dynamic scroller', async () => {
    await createComponentWithData({ numberOfNewFindings: 2 });

    expect(findDynamicScroller().props('items')).toEqual([
      // New findings
      {
        uuid: '1',
        severity: 'critical',
        name: 'Password leak',
        state: 'dismissed',
      },
      { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
      // Fixed findings
      { uuid: '14abc', severity: 'medium', name: 'SQL vulnerability' },
      { uuid: 'bc41e', severity: 'low', name: 'SQL vulnerability 2' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
    expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
  });

  it('contains only fixed findings in the dynamic scroller', async () => {
    await createComponentWithData({
      numberOfNewFindings: 0,
      numberOfFixedFindings: 2,
      findings: [
        { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
        { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
      ],
    });

    expect(findDynamicScroller().props('items')).toEqual([
      { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
      { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').exists()).toBe(false);
    expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
  });

  it('contains only added findings in the dynamic scroller', async () => {
    await createComponentWithData({
      findings: [
        { uuid: '5', severity: 'low', name: 'SQL Injection' },
        { uuid: '3', severity: 'unknown', name: 'Weak password' },
      ],
      numberOfNewFindings: 2,
    });

    expect(findDynamicScroller().props('items')).toEqual([
      { uuid: '5', severity: 'low', name: 'SQL Injection' },
      { uuid: '3', severity: 'unknown', name: 'Weak password' },
    ]);

    expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
    expect(wrapper.findByTestId('fixed-findings-title').exists()).toBe(false);
  });

  describe('error states', () => {
    it('displays an error message for the individual level report', async () => {
      await createComponent({
        propsData: { report: mockReport({ error: true }) },
      });

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(true);
    });
  });

  describe('help popovers', () => {
    it.each`
      reportType               | reportTitle                                      | helpPath
      ${'SAST'}                | ${'Static Application Security Testing (SAST)'}  | ${sastHelp}
      ${'DAST'}                | ${'Dynamic Application Security Testing (DAST)'} | ${dastHelp}
      ${'DEPENDENCY_SCANNING'} | ${'Dependency scanning'}                         | ${dependencyScanningHelp}
      ${'COVERAGE_FUZZING'}    | ${'Coverage fuzzing'}                            | ${coverageFuzzingHelp}
      ${'API_FUZZING'}         | ${'API fuzzing'}                                 | ${apiFuzzingHelp}
      ${'SECRET_DETECTION'}    | ${'Secret detection'}                            | ${secretDetectionHelp}
      ${'CONTAINER_SCANNING'}  | ${'Container scanning'}                          | ${containerScanningHelp}
    `(
      'shows the correct help popover for $reportType',
      async ({ reportType, reportTitle, helpPath }) => {
        await createComponentWithData({ reportType });

        expect(findMrWidgetRow().props('helpPopover')).toMatchObject({
          options: { title: reportTitle },
          content: { learnMorePath: helpPath },
        });
      },
    );
  });

  describe('modal data', () => {
    it('should emit modal-data event when vulnerability is clicked', async () => {
      await createComponentWithData();

      // Click on the vulnerability name
      wrapper.findByText('Password leak').trigger('click');

      expect(wrapper.emitted('modal-data')[0][0]).toEqual({
        name: 'Password leak',
        severity: 'critical',
        state: 'dismissed',
        uuid: '1',
      });
    });
  });
});
