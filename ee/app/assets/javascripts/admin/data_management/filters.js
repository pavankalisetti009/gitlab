import { TOKEN_TYPES } from 'ee/admin/data_management/constants';

export const formatListboxItems = (items) => {
  return items.map((type) => ({
    text: type.titlePlural,
    value: type.name,
  }));
};

export const processFilters = (filters) => {
  // URL Structure: /admin/data_management?${FILTERS}
  const url = new URL(window.location.href);
  const query = {};

  filters.forEach(({ type, value }) => {
    if (type === TOKEN_TYPES.MODEL) {
      query[TOKEN_TYPES.MODEL] = value;
    }
  });

  return { query, url };
};
