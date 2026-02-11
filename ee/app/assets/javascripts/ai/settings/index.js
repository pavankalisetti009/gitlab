import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import { ACCESS_LEVEL_EVERYONE_INTEGER } from './constants';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

const sanitizedInt = (value) => parseInt(value, 10) || ACCESS_LEVEL_EVERYONE_INTEGER;

export const initAiSettings = (id, component, options = {}) => {
  const el = document.getElementById(id);

  if (!el) {
    return false;
  }

  const {
    aiGatewayUrl,
    aiGatewayTimeoutSeconds,
    duoAgentPlatformServiceUrl,
    exposeDuoAgentPlatformServiceUrl,
    canManageSelfHostedModels,
    canConfigureAiLogging,
    duoAvailabilityCascadingSettings,
    duoRemoteFlowsCascadingSettings,
    duoFoundationalFlowsCascadingSettings,
    duoAvailability,
    areDuoSettingsLocked,
    experimentFeaturesEnabled,
    duoCoreFeaturesEnabled,
    duoRemoteFlowsAvailability,
    duoFoundationalFlowsAvailability,
    duoWorkflowsDefaultImageRegistry,
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
    aiUsageDataCollectionAvailable,
    aiUsageDataCollectionEnabled,
    duoWorkflowAvailable,
    promptInjectionProtectionLevel,
    promptInjectionProtectionAvailable,
    isSaas,
    foundationalAgentsDefaultEnabled,
    showFoundationalAgentsAvailability,
    showFoundationalAgentsPerAgentAvailability,
    showDuoAgentPlatformEnablementSetting,
    foundationalAgentsStatuses,
    availableFoundationalFlows,
    selectedFoundationalFlowReferences,
    duoAgentPlatformEnabled,
    namespaceAccessRules,
    parentPath,
    aiMinimumAccessLevelToExecute,
    aiMinimumAccessLevelToExecuteAsync,
  } = el.dataset;

  let duoAvailabilityCascadingSettingsParsed;
  let duoRemoteFlowsCascadingSettingsParsed;
  let duoFoundationalFlowsCascadingSettingsParsed;
  let namespaceAccessRulesParsed;

  try {
    if (namespaceAccessRules) {
      namespaceAccessRulesParsed = convertObjectPropsToCamelCase(JSON.parse(namespaceAccessRules), {
        deep: true,
      });
    }

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

    duoFoundationalFlowsCascadingSettingsParsed = convertObjectPropsToCamelCase(
      JSON.parse(duoFoundationalFlowsCascadingSettings),
      {
        deep: true,
      },
    );
  } catch {
    duoAvailabilityCascadingSettingsParsed = null;
  }

  const parsedFoundationalAgentsStatuses = foundationalAgentsStatuses
    ? convertObjectPropsToCamelCase(JSON.parse(foundationalAgentsStatuses), {
        deep: true,
      }).map((agent) => ({
        ...agent,
        enabled: agent.enabled === null ? null : parseBoolean(agent.enabled),
      }))
    : [];

  return new Vue({
    el,
    apolloProvider,
    provide: {
      aiGatewayUrl,
      aiGatewayTimeoutSeconds: parseInt(aiGatewayTimeoutSeconds, 10),
      duoAgentPlatformServiceUrl,
      exposeDuoAgentPlatformServiceUrl: parseBoolean(exposeDuoAgentPlatformServiceUrl),
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      canConfigureAiLogging: parseBoolean(canConfigureAiLogging),
      duoAvailabilityCascadingSettings: duoAvailabilityCascadingSettingsParsed,
      duoRemoteFlowsCascadingSettings: duoRemoteFlowsCascadingSettingsParsed,
      duoFoundationalFlowsCascadingSettings: duoFoundationalFlowsCascadingSettingsParsed,
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked),
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      duoCoreFeaturesEnabled: parseBoolean(duoCoreFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      disabledDirectConnectionMethod: parseBoolean(disabledDirectConnectionMethod),
      showEarlyAccessBanner: parseBoolean(showEarlyAccessBanner),
      duoWorkflowMcpEnabled: parseBoolean(duoWorkflowMcpEnabled),
      duoWorkflowAvailable: parseBoolean(duoWorkflowAvailable),
      promptInjectionProtectionLevel,
      promptInjectionProtectionAvailable: parseBoolean(promptInjectionProtectionAvailable),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      foundationalAgentsDefaultEnabled: parseBoolean(foundationalAgentsDefaultEnabled),
      showFoundationalAgentsAvailability: parseBoolean(showFoundationalAgentsAvailability),
      showFoundationalAgentsPerAgentAvailability: parseBoolean(
        showFoundationalAgentsPerAgentAvailability,
      ),
      showDuoAgentPlatformEnablementSetting: parseBoolean(showDuoAgentPlatformEnablementSetting),
      initialFoundationalAgentsStatuses: parsedFoundationalAgentsStatuses,
      initialDuoAgentPlatformEnabled: parseBoolean(duoAgentPlatformEnabled),
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
      aiUsageDataCollectionAvailable: parseBoolean(aiUsageDataCollectionAvailable),
      aiUsageDataCollectionEnabled: parseBoolean(aiUsageDataCollectionEnabled),
      initialDuoRemoteFlowsAvailability: parseBoolean(duoRemoteFlowsAvailability),
      initialDuoFoundationalFlowsAvailability: parseBoolean(duoFoundationalFlowsAvailability),
      initialDuoWorkflowsDefaultImageRegistry: duoWorkflowsDefaultImageRegistry || '',
      isSaaS: parseBoolean(isSaas),
      isGroupSettings: options?.isGroupSettings || false,
      availableFoundationalFlows: (() => {
        const flows = availableFoundationalFlows ? JSON.parse(availableFoundationalFlows) : [];
        return flows;
      })(),
      initialSelectedFoundationalFlowIds: (() => {
        const selected = selectedFoundationalFlowReferences
          ? JSON.parse(selectedFoundationalFlowReferences)
          : [];
        return selected;
      })(),
      initialNamespaceAccessRules: namespaceAccessRulesParsed,
      parentPath,
      initialMinimumAccessLevelExecuteSync: sanitizedInt(aiMinimumAccessLevelToExecute),
      initialMinimumAccessLevelExecuteAsync: sanitizedInt(aiMinimumAccessLevelToExecuteAsync),
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
