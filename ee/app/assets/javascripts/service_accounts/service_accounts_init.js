import Vue from 'vue';
import { createPinia, PiniaVuePlugin } from 'pinia';
import createRouter from './router';

import app from './service_accounts_app.vue';

Vue.use(PiniaVuePlugin);

export default (el) => {
  if (!el) {
    return null;
  }

  const { basePath, serviceAccountsPath, serviceAccountsDocsPath } = el.dataset;

  const pinia = createPinia();
  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'ServiceAccountsRoot',
    router,
    pinia,
    provide: {
      serviceAccountsPath,
      serviceAccountsDocsPath,
    },
    render(createElement) {
      return createElement(app);
    },
  });
};
