import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import AiCatalogBreadcrumbs from './router/ai_catalog_breadcrumbs.vue';
import typeDefs from './graphql/typedefs.graphql';
import itemToDuplicateQuery from './graphql/queries/item_to_duplicate.query.graphql';

import AiCatalogApp from './ai_catalog_app.vue';
import { createRouter } from './router';

export const initAiCatalog = (selector = '#js-ai-catalog') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const { dataset } = el;
  const { aiCatalogIndexPath } = dataset;

  Vue.use(VueApollo);
  Vue.use(GlToast);

  const router = createRouter(aiCatalogIndexPath);

  const resolvers = {
    Mutation: {
      setItemToDuplicate(_, { item }, { cache }) {
        cache.writeQuery({
          query: itemToDuplicateQuery,
          data: { itemToDuplicate: item },
        });
        return item;
      },
    },
  };

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(resolvers, {
      typeDefs,
      cacheConfig: {
        typePolicies: {
          Query: {
            fields: {
              itemToDuplicate: {
                read(currentState) {
                  return currentState || null;
                },
              },
            },
          },
        },
      },
    }),
  });

  injectVueAppBreadcrumbs(router, AiCatalogBreadcrumbs);

  return new Vue({
    el,
    name: 'AiCatalogRoot',
    router,
    apolloProvider,
    render(h) {
      return h(AiCatalogApp);
    },
  });
};
