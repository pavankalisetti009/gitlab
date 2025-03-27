import Vue from 'vue';
import { pinia } from '~/pinia/instance';

import createRouter from './router';
import app from './service_accounts_app.vue';

export default (el) => {
  if (!el) {
    return null;
  }

  const {
    basePath,
    serviceAccountsPath,
    serviceAccountsDeletePath,
    serviceAccountsDocsPath,
    accessTokenMaxDate,
    accessTokenMinDate,
    accessTokenCreate,
    accessTokenRevoke,
    accessTokenRotate,
    accessTokenShow,
  } = el.dataset;

  const router = createRouter(basePath);

  return new Vue({
    el,
    name: 'ServiceAccountsRoot',
    router,
    pinia,
    provide: {
      serviceAccountsPath,
      serviceAccountsDocsPath,
      accessTokenMaxDate,
      accessTokenMinDate,
      accessTokenCreate,
      serviceAccountsDeletePath,
      accessTokenRevoke,
      accessTokenRotate,
      accessTokenShow,
    },
    render(createElement) {
      return createElement(app);
    },
  });
};
