import { parseBoolean } from '~/lib/utils/common_utils';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';
import findingsQuery from 'ee/security_dashboard/graphql/queries/pipeline_findings.query.graphql';

export const getPipelineReportOptions = (data) => {
  const {
    projectFullPath,
    emptyStateSvgPath,
    canAdminVulnerability,
    pipelineId,
    pipelineIid,
    pipelineJobsPath,
    sourceBranch,
    canViewFalsePositive,
    hasJiraVulnerabilitiesIntegrationEnabled,
  } = data;

  return {
    projectFullPath,
    emptyStateSvgPath,
    dashboardType: DASHBOARD_TYPES.PIPELINE,
    // fullPath is needed even though projectFullPath is already provided because
    // vulnerability_list_graphql.vue expects the property name to be 'fullPath'
    fullPath: projectFullPath,
    canAdminVulnerability: parseBoolean(canAdminVulnerability),
    pipeline: {
      id: Number(pipelineId),
      iid: Number(pipelineIid),
      jobsPath: pipelineJobsPath,
      sourceBranch,
    },
    canViewFalsePositive: parseBoolean(canViewFalsePositive),
    vulnerabilitiesQuery: findingsQuery,
    hasJiraVulnerabilitiesIntegrationEnabled: parseBoolean(
      hasJiraVulnerabilitiesIntegrationEnabled,
    ),
  };
};
