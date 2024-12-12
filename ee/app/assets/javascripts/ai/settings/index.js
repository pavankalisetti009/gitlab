import Vue from 'vue';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

export const initAiSettings = (id, component) => {
  const el = document.getElementById(id);

  if (!el) {
    return false;
  }

  const {
    cascadingSettingsData,
    duoAvailability,
    areDuoSettingsLocked,
    experimentFeaturesEnabled,
    areExperimentSettingsAllowed,
    redirectPath,
    updateId,
    duoProVisible,
    disabledDirectConnectionMethod,
    showEarlyAccessBanner,
    earlyAccessPath,
    selfHostedModelsEnabled,
    aiTermsAndConditionsPath,
    onGeneralSettingsPage,
    configurationSettingsPath,
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
    provide: {
      cascadingSettingsData: cascadingSettingsDataParsed,
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      disabledDirectConnectionMethod: parseBoolean(disabledDirectConnectionMethod),
      showEarlyAccessBanner: parseBoolean(showEarlyAccessBanner),
      selfHostedModelsEnabled: parseBoolean(selfHostedModelsEnabled),
      aiTermsAndConditionsPath,
      earlyAccessPath,
      onGeneralSettingsPage: parseBoolean(onGeneralSettingsPage),
      configurationSettingsPath,
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
