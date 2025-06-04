export const MOCK_LISTBOX_ITEMS = [
  {
    text: 'Listbox A',
    value: 'listbox_a',
  },
  {
    text: 'Listbox B',
    value: 'listbox_b',
  },
  {
    text: 'Listbox C',
    value: 'listbox_c',
  },
];

export const MOCK_FILTER_A = {
  type: 'filter_a',
  value: {
    data: 'value_a',
  },
};

export const MOCK_FILTER_B = {
  type: 'filter_b',
  value: {
    data: 'value_b',
  },
};

export const MOCK_FILTERED_SEARCH_TOKENS = [
  {
    title: 'Filter A',
    type: MOCK_FILTER_A.type,
    options: [MOCK_FILTER_A.value.data],
  },
  {
    title: 'Filter B',
    type: MOCK_FILTER_B.type,
    options: [MOCK_FILTER_B.value.data],
  },
];
