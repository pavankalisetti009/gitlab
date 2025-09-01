import { pathSegments } from '~/lib/utils/url_utility';
import { isGid, convertToGraphQLId } from '~/graphql_shared/utils';
import { FILTERED_SEARCH_TOKENS, TOKEN_TYPES, DEFAULT_CURSOR } from './constants';

export const formatListboxItems = (items) => {
  return items.map((type) => ({
    text: type.titlePlural,
    value: type.namePlural,
  }));
};

export const isValidFilter = (data, array) => {
  return data && array?.some(({ value }) => value === data);
};

export const getReplicableTypeFilter = (value) => {
  return {
    type: TOKEN_TYPES.REPLICABLE_TYPE,
    value,
  };
};

export const getReplicationStatusFilter = (data) => {
  return {
    type: TOKEN_TYPES.REPLICATION_STATUS,
    value: {
      data,
    },
  };
};

export const getVerificationStatusFilter = (data) => {
  return {
    type: TOKEN_TYPES.VERIFICATION_STATUS,
    value: {
      data,
    },
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

    // ids is stored as " " separated String in filtered search
    if (typeof filter === 'string') {
      query[TOKEN_TYPES.IDS] = filter;
    }

    if (filter.type === TOKEN_TYPES.REPLICATION_STATUS) {
      query[TOKEN_TYPES.REPLICATION_STATUS] = filter.value.data;
    }

    if (filter.type === TOKEN_TYPES.VERIFICATION_STATUS) {
      query[TOKEN_TYPES.VERIFICATION_STATUS] = filter.value.data;
    }
  });

  return { query, url };
};

export const formatGraphqlIds = ({ ids, graphqlRegistryClass }) => {
  if (!ids) {
    return null;
  }

  try {
    return ids.split(' ').map((id) => {
      if (isGid(id)) {
        return id;
      }

      const sanitizedId = id.replace(`${graphqlRegistryClass}/`, '');
      return convertToGraphQLId(graphqlRegistryClass, sanitizedId);
    });
  } catch {
    return null;
  }
};

export const getGraphqlFilterVariables = ({ filters, graphqlRegistryClass }) => {
  const variables = {
    replicationState: null,
    verificationState: null,
    ids: null,
  };

  // ids is stored as " " separated String in filtered search
  variables.ids = formatGraphqlIds({
    ids: filters.find((filter) => typeof filter === 'string'),
    graphqlRegistryClass,
  });

  variables.replicationState =
    filters
      .find(({ type }) => type === TOKEN_TYPES.REPLICATION_STATUS)
      ?.value?.data?.toUpperCase() || null;

  variables.verificationState =
    filters
      .find(({ type }) => type === TOKEN_TYPES.VERIFICATION_STATUS)
      ?.value?.data?.toUpperCase() || null;

  return variables;
};

export const getAvailableFilteredSearchTokens = (verificationEnabled) => {
  if (verificationEnabled) {
    return FILTERED_SEARCH_TOKENS;
  }

  return FILTERED_SEARCH_TOKENS.filter((filter) => filter.type !== TOKEN_TYPES.VERIFICATION_STATUS);
};

export const getPaginationObject = ({ before = '', after = '', first, last } = {}) => {
  const paginationObject = {
    ...DEFAULT_CURSOR,
    before,
    after,
  };

  const firstNum = parseInt(first, 10);
  const lastNum = parseInt(last, 10);

  if (firstNum > 0) {
    paginationObject.first = firstNum;
    paginationObject.last = null;
  } else if (lastNum > 0) {
    paginationObject.first = null;
    paginationObject.last = lastNum;
  }

  return paginationObject;
};
