import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getGraphqlClient } from 'ee/geo_shared/graphql/geo_client';
import GeoReplicableApp from './components/app.vue';
import createStore from './store';
import { formatListboxItems } from './filters';
import { FILTERED_SEARCH_TOKENS } from './constants';

export default () => {
  const el = document.getElementById('js-geo-replicable');
  const { geoCurrentSiteId, geoTargetSiteId, geoTargetSiteName, replicableBasePath } = el.dataset;

  const replicableTypes = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicableTypes), {
    deep: true,
  });

  const replicableClass = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicatorClassData));

  const apolloProvider = new VueApollo({
    defaultClient: getGraphqlClient(geoCurrentSiteId, geoTargetSiteId),
  });

  return new Vue({
    el,
    apolloProvider,
    // TODO: This will be fully removed as part of https://gitlab.com/gitlab-org/gitlab/-/issues/425584
    store: createStore({
      titlePlural: replicableClass.titlePlural,
      graphqlMutationRegistryClass: replicableClass.graphqlMutationRegistryClass,
      geoCurrentSiteId: replicableClass.geoCurrentSiteId,
      geoTargetSiteId: replicableClass.geoTargetSiteId,
    }),
    provide: {
      replicableBasePath,
      replicableTypes,
      siteName: geoTargetSiteName,
      replicableClass,
      itemTitle: replicableClass.titlePlural, // itemTitle is used by a few geo_shared/ components
      listboxItems: formatListboxItems(replicableTypes),
      filteredSearchTokens: FILTERED_SEARCH_TOKENS,
    },

    render(createElement) {
      return createElement(GeoReplicableApp);
    },
  });
};
