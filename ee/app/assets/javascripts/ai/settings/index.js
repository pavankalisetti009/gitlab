import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initAiSettings = (id, component) => {
  const el = document.getElementById(id);

  if (!el) {
    return false;
  }

  const {
    aiGatewayUrl,
    canManageSelfHostedModels,
    cascadingSettingsData,
    duoAvailability,
    areDuoSettingsLocked,
    experimentFeaturesEnabled,
    duoCoreFeaturesEnabled,
    redirectPath,
    updateId,
    duoProVisible,
    disabledDirectConnectionMethod,
    showEarlyAccessBanner,
    earlyAccessPath,
    betaSelfHostedModelsEnabled,
    toggleBetaModelsPath,
    amazonQAvailable,
    amazonQAutoReviewEnabled,
    onGeneralSettingsPage,
    areExperimentSettingsAllowed,
    isDuoBaseAccessAllowed,
    enabledExpandedLogging,
    duoChatExpirationDays,
    duoChatExpirationColumn,
    duoProOrDuoEnterpriseTier,
  } = el.dataset;

  let cascadingSettingsDataParsed;
  try {
    cascadingSettingsDataParsed = convertObjectPropsToCamelCase(JSON.parse(cascadingSettingsData), {
      deep: true,
    });
  } catch {
    cascadingSettingsDataParsed = null;
  }

  return new Vue({
    el,
    apolloProvider,
    provide: {
      aiGatewayUrl,
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      cascadingSettingsData: cascadingSettingsDataParsed,
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked),
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      duoCoreFeaturesEnabled: parseBoolean(duoCoreFeaturesEnabled),
      disabledDirectConnectionMethod: parseBoolean(disabledDirectConnectionMethod),
      showEarlyAccessBanner: parseBoolean(showEarlyAccessBanner),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      toggleBetaModelsPath,
      enabledExpandedLogging: parseBoolean(enabledExpandedLogging),
      earlyAccessPath,
      amazonQAvailable: parseBoolean(amazonQAvailable),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      onGeneralSettingsPage: parseBoolean(onGeneralSettingsPage),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      isDuoBaseAccessAllowed: parseBoolean(isDuoBaseAccessAllowed),
      duoChatExpirationDays: parseInt(duoChatExpirationDays, 10),
      duoChatExpirationColumn,
      duoProOrDuoEnterpriseTier,
    },
    render: (createElement) =>
      createElement(component, {
        props: {
          redirectPath,
          updateId,
          duoProVisible: parseBoolean(duoProVisible),
        },
      }),
  });
};
