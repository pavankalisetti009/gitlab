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
    duoSeatUtilizationPath,
    isBulkAddOnAssignmentEnabled,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    duoConfigurationPath,
    duoAvailability,
    directCodeSuggestionsEnabled,
    experimentFeaturesEnabled,
    betaSelfHostedModelsEnabled,
    areExperimentSettingsAllowed,
    duoAddOnStartDate,
    duoAddOnEndDate,
    amazonQReady,
    amazonQAutoReviewEnabled,
    amazonQConfigurationPath,
    duoWorkflowEnabled,
    duoWorkflowServiceAccount,
    isSaas,
    duoWorkflowSettingsPath,
    redirectPath,
    duoWorkflowDisablePath,
  } = el.dataset;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide: {
      isSaaS: parseBoolean(isSaas),
      addDuoProHref: addDuoProSeatsUrl,
      duoSeatUtilizationPath,
      isBulkAddOnAssignmentEnabled: parseBoolean(isBulkAddOnAssignmentEnabled),
      subscriptionName,
      subscriptionStartDate,
      subscriptionEndDate,
      duoConfigurationPath,
      duoAvailability,
      directCodeSuggestionsEnabled: parseBoolean(directCodeSuggestionsEnabled),
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      duoAddOnStartDate,
      duoAddOnEndDate,
      amazonQReady: parseBoolean(amazonQReady),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      amazonQConfigurationPath,
      duoWorkflowEnabled: parseBoolean(duoWorkflowEnabled),
      duoWorkflowServiceAccount: duoWorkflowServiceAccount
        ? JSON.parse(duoWorkflowServiceAccount)
        : undefined,
      duoWorkflowSettingsPath,
      redirectPath,
      duoWorkflowDisablePath,
    },
    render: (h) => h(GitlabDuoHome),
  });
}

mountGitlabDuoHomeApp();
