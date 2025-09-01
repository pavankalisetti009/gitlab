import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import Translate from '~/vue_shared/translate';
import WorkItemSettings from './work_item_settings.vue';
import { getRoutes } from './routes';

Vue.use(VueApollo);
Vue.use(Translate);
Vue.use(VueRouter);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initWorkItemSettingsApp() {
  const el = document.querySelector('#js-work-items-settings-form');
  if (!el) return;

  const { fullPath, basePath } = el.dataset;

  // eslint-disable-next-line no-new
  new Vue({
    el,
    apolloProvider,
    router: new VueRouter({
      mode: 'history',
      base: basePath,
      routes: getRoutes(fullPath),
    }),
    render(createElement) {
      return createElement(WorkItemSettings, {
        props: {
          fullPath,
        },
      });
    },
  });
}
