import Vue from 'vue';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { buildCycleAnalyticsInitialData } from 'ee/analytics/shared/utils';
import createStore from '../store';
import VSASettingsApp from './components/app.vue';

export default () => {
  const el = document.getElementById('js-vsa-settings-app');
  if (!el) return false;

  const { isEditPage, vsaPath, namespaceFullPath, stageEvents: rawStageEvents } = el.dataset;
  const initialData = buildCycleAnalyticsInitialData(el.dataset);
  const store = createStore();

  store.dispatch('initializeCycleAnalytics', initialData);

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

  return new Vue({
    el,
    store,
    provide: {
      vsaPath,
      namespaceFullPath,
      stageEvents,
    },
    render: (createElement) =>
      createElement(VSASettingsApp, {
        props: {
          isEditing: parseBoolean(isEditPage),
        },
      }),
  });
};
