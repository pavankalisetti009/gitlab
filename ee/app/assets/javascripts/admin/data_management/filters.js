import { TOKEN_TYPES } from 'ee/admin/data_management/constants';

export const formatListboxItems = (items) => {
  return items.map((type) => ({
    text: type.titlePlural,
    value: type.name,
  }));
};

export const isValidFilter = (data, array) => {
  return Boolean(data && array?.some(({ value }) => value === data));
};

const filterProcessors = [
  {
    key: TOKEN_TYPES.IDENTIFIERS,
    // identifiers are stored as " " separated String in filtered search
    condition: (filter) => typeof filter === 'string',
    transform: (filter) => filter.split(' '),
  },
  {
    key: TOKEN_TYPES.MODEL,
    condition: (filter) => filter.type === TOKEN_TYPES.MODEL,
    transform: (filter) => filter.value,
  },
  {
    key: TOKEN_TYPES.CHECKSUM_STATE,
    condition: (filter) => filter.type === TOKEN_TYPES.CHECKSUM_STATE,
    transform: (filter) => filter.value.data,
  },
];

export const processFilters = (filters) => {
  // URL Structure: /admin/data_management?${FILTERS}
  const url = new URL(window.location.href);

  const query = filters.reduce((acc, filter) => {
    const matchingProcessor = filterProcessors.find(({ condition }) => condition(filter));
    if (!matchingProcessor) return acc;

    const { key, transform } = matchingProcessor;
    return { ...acc, [key]: transform(filter) };
  }, {});

  return { query, url };
};
