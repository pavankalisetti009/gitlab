import Vue from 'vue';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import VSASettingsApp from './components/app.vue';

export default () => {
  const el = document.getElementById('js-vsa-settings-app');
  if (!el) return false;

  const {
    isEditPage,
    vsaPath,
    namespaceFullPath,
    defaultStages: rawDefaultStages,
    stageEvents: rawStageEvents,
    valueStream: rawValueStream,
  } = el.dataset;

  let stageEvents = [];
  try {
    stageEvents = JSON.parse(rawStageEvents).map((ev) =>
      convertObjectPropsToCamelCase(ev, { deep: true }),
    );
  } catch (e) {
    createAlert({
      message: s__('CycleAnalytics|Failed to parse stage events.'),
    });
    return false;
  }

  let valueStream = {};
  if (rawValueStream) {
    try {
      valueStream = convertObjectPropsToCamelCase(JSON.parse(rawValueStream));
    } catch (e) {
      createAlert({
        message: s__('CycleAnalytics|Failed to parse value stream.'),
      });
      return false;
    }
  }

  let defaultStages = [];
  if (rawDefaultStages) {
    try {
      defaultStages = JSON.parse(rawDefaultStages).map(({ name, ...rest }) => ({
        ...convertObjectPropsToCamelCase(rest),
        name: capitalizeFirstCharacter(name),
      }));
    } catch (e) {
      createAlert({
        message: s__('CycleAnalytics|Failed to parse default stages.'),
      });
      return false;
    }
  }

  return new Vue({
    el,
    provide: {
      vsaPath,
      namespaceFullPath,
      stageEvents,
      valueStream,
      defaultStages,
      isEditing: parseBoolean(isEditPage),
    },
    render: (createElement) => createElement(VSASettingsApp),
  });
};
