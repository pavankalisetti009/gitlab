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
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked) || false,
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed) || true,
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled) || false,
    },
    render: (createElement) =>
      createElement(component, {
        props: {
          redirectPath,
          updateId,
        },
      }),
  });
};
