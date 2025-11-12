import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initAiSettings = (id, component, options = {}) => {
  const el = document.getElementById(id);

  if (!el) {
    return false;
  }

  const {
    aiGatewayUrl,
    duoAgentPlatformServiceUrl,
    exposeDuoAgentPlatformServiceUrl,
    canManageSelfHostedModels,
    duoAvailabilityCascadingSettings,
    duoRemoteFlowsCascadingSettings,
    duoAvailability,
    areDuoSettingsLocked,
    experimentFeaturesEnabled,
    duoCoreFeaturesEnabled,
    duoRemoteFlowsAvailability,
    promptCacheEnabled,
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
    arePromptCacheSettingsAllowed,
    enabledExpandedLogging,
    duoChatExpirationDays,
    duoChatExpirationColumn,
    duoWorkflowMcpEnabled,
    duoWorkflowAvailable,
    isSaas,
    foundationalAgentsDefaultEnabled,
    showFoundationalAgentsAvailability,
  } = el.dataset;

  let duoAvailabilityCascadingSettingsParsed;
  let duoRemoteFlowsCascadingSettingsParsed;

  try {
    duoAvailabilityCascadingSettingsParsed = convertObjectPropsToCamelCase(
      JSON.parse(duoAvailabilityCascadingSettings),
      {
        deep: true,
      },
    );

    duoRemoteFlowsCascadingSettingsParsed = convertObjectPropsToCamelCase(
      JSON.parse(duoRemoteFlowsCascadingSettings),
      {
        deep: true,
      },
    );
  } catch {
    duoAvailabilityCascadingSettingsParsed = null;
  }

  return new Vue({
    el,
    apolloProvider,
    provide: {
      aiGatewayUrl,
      duoAgentPlatformServiceUrl,
      exposeDuoAgentPlatformServiceUrl: parseBoolean(exposeDuoAgentPlatformServiceUrl),
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      duoAvailabilityCascadingSettings: duoAvailabilityCascadingSettingsParsed,
      duoRemoteFlowsCascadingSettings: duoRemoteFlowsCascadingSettingsParsed,
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked),
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      duoCoreFeaturesEnabled: parseBoolean(duoCoreFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      disabledDirectConnectionMethod: parseBoolean(disabledDirectConnectionMethod),
      showEarlyAccessBanner: parseBoolean(showEarlyAccessBanner),
      duoWorkflowMcpEnabled: parseBoolean(duoWorkflowMcpEnabled),
      duoWorkflowAvailable: parseBoolean(duoWorkflowAvailable),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      foundationalAgentsDefaultEnabled: parseBoolean(foundationalAgentsDefaultEnabled),
      showFoundationalAgentsAvailability: parseBoolean(showFoundationalAgentsAvailability),
      toggleBetaModelsPath,
      enabledExpandedLogging: parseBoolean(enabledExpandedLogging),
      earlyAccessPath,
      amazonQAvailable: parseBoolean(amazonQAvailable),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      onGeneralSettingsPage: parseBoolean(onGeneralSettingsPage),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      arePromptCacheSettingsAllowed: parseBoolean(arePromptCacheSettingsAllowed),
      duoChatExpirationDays: parseInt(duoChatExpirationDays, 10),
      duoChatExpirationColumn,
      initialDuoRemoteFlowsAvailability: parseBoolean(duoRemoteFlowsAvailability),
      isSaaS: parseBoolean(isSaas),
      isGroupSettings: options?.isGroupSettings || false,
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
