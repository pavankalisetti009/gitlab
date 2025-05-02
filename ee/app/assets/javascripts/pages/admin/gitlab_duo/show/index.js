import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import initEnableDuoBannerSM from 'ee/ai/init_enable_duo_banner_sm';

export function mountGitlabDuoHomeApp() {
  const el = document.getElementById('js-gitlab-duo-admin-page');

  if (!el) {
    return null;
  }

  const {
    addDuoProSeatsUrl,
    duoSeatUtilizationPath,
    isBulkAddOnAssignmentEnabled,
    isDuoBaseAccessAllowed,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    duoConfigurationPath,
    duoSelfHostedPath,
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
    canManageSelfHostedModels,
    areDuoCoreFeaturesEnabled,
  } = el.dataset;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide: {
      isSaaS: false,
      addDuoProHref: addDuoProSeatsUrl,
      duoSeatUtilizationPath,
      isBulkAddOnAssignmentEnabled: parseBoolean(isBulkAddOnAssignmentEnabled),
      isDuoBaseAccessAllowed: parseBoolean(isDuoBaseAccessAllowed),
      subscriptionName,
      subscriptionStartDate,
      subscriptionEndDate,
      duoConfigurationPath,
      duoSelfHostedPath,
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
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      areDuoCoreFeaturesEnabled: parseBoolean(areDuoCoreFeaturesEnabled),
    },
    render: (h) => h(GitlabDuoHome),
  });
}

mountGitlabDuoHomeApp();
initEnableDuoBannerSM();
