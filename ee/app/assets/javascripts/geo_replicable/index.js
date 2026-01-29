import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getGraphqlClient } from 'ee/geo_shared/graphql/geo_client';
import GeoReplicableApp from './components/app.vue';
import {
  formatListboxItems,
  getAvailableFilteredSearchTokens,
  getAvailableSortOptions,
} from './filters';

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
    name: 'GeoReplicableAppRoot',
    apolloProvider,
    provide: {
      replicableBasePath,
      replicableTypes,
      siteName: geoTargetSiteName,
      replicableClass,
      itemTitle: replicableClass.titlePlural, // itemTitle is used by a few geo_shared/ components
      listboxItems: formatListboxItems(replicableTypes),
      filteredSearchTokens: getAvailableFilteredSearchTokens(replicableClass.verificationEnabled),
      sortOptions: getAvailableSortOptions(replicableClass.verificationEnabled),
    },

    render(createElement) {
      return createElement(GeoReplicableApp);
    },
  });
};
