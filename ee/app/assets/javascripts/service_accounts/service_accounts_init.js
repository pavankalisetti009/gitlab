import Vue from 'vue';
import { pinia } from '~/pinia/instance';

import createRouter from './router';
import app from './service_accounts_app.vue';

export default (el) => {
  if (!el) {
    return null;
  }

  const { basePath, serviceAccountsPath, serviceAccountsDocsPath, accessTokenShow } = el.dataset;

  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'ServiceAccountsRoot',
    router,
    pinia,
    provide: {
      serviceAccountsPath,
      serviceAccountsDocsPath,
      accessTokenShow,
    },
    render(createElement) {
      return createElement(app);
    },
  });
};
