import { pathSegments } from '~/lib/utils/url_utility';
import { TOKEN_TYPES } from './constants';

export const getReplicableTypeFilter = (value) => {
  return {
    type: TOKEN_TYPES.REPLICABLE_TYPE,
    value,
  };
};

export const processFilters = (filters) => {
  // URL Structure: /admin/geo/sites/${SITE_ID}/replication/${REPLICABLE_TYPE}?${FILTERS}
  const url = new URL(window.location.href);
  const query = {};

  filters.forEach((filter) => {
    if (filter.type === TOKEN_TYPES.REPLICABLE_TYPE) {
      const segments = pathSegments(url);
      segments[segments.length - 1] = filter.value;
      url.pathname = segments.join('/');
    }
  });

  return { query, url };
};
