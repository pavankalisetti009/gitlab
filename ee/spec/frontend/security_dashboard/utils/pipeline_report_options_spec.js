import { getPipelineReportOptions } from 'ee/security_dashboard/utils/pipeline_report_options';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';
import findingsQuery from 'ee/security_dashboard/graphql/queries/pipeline_findings.query.graphql';
import { dataset } from '../mock_data/pipeline_report_dataset';

describe('getPipelineReportOptions', () => {
  it('returns pipeline report options', () => {
    expect(getPipelineReportOptions(dataset)).toEqual({
      projectFullPath: dataset.projectFullPath,
      emptyStateSvgPath: dataset.emptyStateSvgPath,
      dashboardType: DASHBOARD_TYPES.PIPELINE,
      fullPath: dataset.projectFullPath,
      canAdminVulnerability: true,
      pipeline: {
        id: 500,
        iid: 43,
        jobsPath: dataset.pipelineJobsPath,
        sourceBranch: dataset.sourceBranch,
      },
      canViewFalsePositive: true,
      vulnerabilitiesQuery: findingsQuery,
      hasJiraVulnerabilitiesIntegrationEnabled: false,
    });
  });

  it('throws if no dataset is provided', () => {
    expect(() => {
      getPipelineReportOptions();
    }).toThrow();
  });
});
