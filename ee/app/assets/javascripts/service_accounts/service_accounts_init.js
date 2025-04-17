import Vue from 'vue';
import { pinia } from '~/pinia/instance';
import { parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import ServiceAccountsBreadcrumb from './components/service_accounts_breadcrumb.vue';

import createRouter from './router';
import app from './service_accounts_app.vue';

export default (el) => {
  if (!el) {
    return null;
  }

  const {
    basePath,
    isGroup,
    serviceAccountsPath,
    serviceAccountsDeletePath,
    serviceAccountsDocsPath,
    accessTokenMaxDate,
    accessTokenMinDate,
    accessTokenCreate,
    serviceAccountsEditPath,
    accessTokenRevoke,
    accessTokenRotate,
    accessTokenShow,
  } = el.dataset;

  const router = createRouter(basePath);

  injectVueAppBreadcrumbs(router, ServiceAccountsBreadcrumb);

  return new Vue({
    el,
    name: 'ServiceAccountsRoot',
    router,
    pinia,
    provide: {
      isGroup: parseBoolean(isGroup),
      serviceAccountsPath,
      serviceAccountsDocsPath,
      accessTokenMaxDate,
      accessTokenMinDate,
      accessTokenCreate,
      serviceAccountsEditPath,
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
