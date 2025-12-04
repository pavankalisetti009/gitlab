import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { parseBoolean } from '~/lib/utils/common_utils';
import AiCatalogBreadcrumbs from './router/ai_catalog_breadcrumbs.vue';

import AiCatalogApp from './ai_catalog_app.vue';
import { createRouter } from './router';

export const initAiCatalog = (selector = '#js-ai-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { aiCatalogIndexPath, aiImpactDashboardEnabled } = dataset;

  Vue.use(VueApollo);
  Vue.use(GlToast);

  const router = createRouter(aiCatalogIndexPath);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  injectVueAppBreadcrumbs(router, AiCatalogBreadcrumbs);

  return new Vue({
    el,
    name: 'AiCatalogRoot',
    router,
    apolloProvider,
    provide: {
      isGlobal: true,
      aiImpactDashboardEnabled: parseBoolean(aiImpactDashboardEnabled),
    },
    render(h) {
      return h(AiCatalogApp);
    },
  });
};
