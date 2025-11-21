import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';

export function mountGitlabDuoHomeApp() {
  const el = document.getElementById('js-gitlab-duo-admin-page');

  if (!el) {
    return null;
  }

  const {
    addDuoProSeatsUrl,
    aiGatewayUrl,
    duoAgentPlatformServiceUrl,
    exposeDuoAgentPlatformServiceUrl,
    duoSeatUtilizationPath,
    enabledExpandedLogging,
    isBulkAddOnAssignmentEnabled,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    duoConfigurationPath,
    duoSelfHostedPath,
    duoAvailability,
    directCodeSuggestionsEnabled,
    experimentFeaturesEnabled,
    promptCacheEnabled,
    betaSelfHostedModelsEnabled,
    areExperimentSettingsAllowed,
    arePromptCacheSettingsAllowed,
    duoAddOnStartDate,
    duoAddOnEndDate,
    amazonQReady,
    amazonQAutoReviewEnabled,
    amazonQConfigurationPath,
    canManageSelfHostedModels,
    canManageInstanceModelSelection,
    areDuoCoreFeaturesEnabled,
    duoRemoteFlowsAvailability,
    duoFoundationalFlowsAvailability,
    duoWorkflowEnabled,
    duoWorkflowServiceAccount,
    isSaas,
    duoWorkflowSettingsPath,
    redirectPath,
    duoWorkflowDisablePath,
    usageDashboardPath,
  } = el.dataset;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide: {
      aiGatewayUrl,
      duoAgentPlatformServiceUrl,
      exposeDuoAgentPlatformServiceUrl: parseBoolean(exposeDuoAgentPlatformServiceUrl),
      isSaaS: parseBoolean(isSaas),
      isAdminInstanceDuoHome: true,
      addDuoProHref: addDuoProSeatsUrl,
      duoSeatUtilizationPath,
      isBulkAddOnAssignmentEnabled: parseBoolean(isBulkAddOnAssignmentEnabled),
      subscriptionName,
      subscriptionStartDate,
      subscriptionEndDate,
      duoConfigurationPath,
      duoSelfHostedPath,
      duoAvailability,
      directCodeSuggestionsEnabled: parseBoolean(directCodeSuggestionsEnabled),
      expandedLoggingEnabled: parseBoolean(enabledExpandedLogging),
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      arePromptCacheSettingsAllowed: parseBoolean(arePromptCacheSettingsAllowed),
      duoAddOnStartDate,
      duoAddOnEndDate,
      amazonQReady: parseBoolean(amazonQReady),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      amazonQConfigurationPath,
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      canManageInstanceModelSelection: parseBoolean(canManageInstanceModelSelection),
      areDuoCoreFeaturesEnabled: parseBoolean(areDuoCoreFeaturesEnabled),
      initialDuoRemoteFlowsAvailability: parseBoolean(duoRemoteFlowsAvailability),
      initialDuoFoundationalFlowsAvailability: parseBoolean(duoFoundationalFlowsAvailability),
      duoWorkflowEnabled: parseBoolean(duoWorkflowEnabled),
      duoWorkflowServiceAccount: duoWorkflowServiceAccount
        ? JSON.parse(duoWorkflowServiceAccount)
        : undefined,
      duoWorkflowSettingsPath,
      redirectPath,
      duoWorkflowDisablePath,
      usageDashboardPath,
    },
    render: (h) => h(GitlabDuoHome),
  });
}

mountGitlabDuoHomeApp();
