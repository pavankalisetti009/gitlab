import {
  formatListboxItems,
  processFilters,
  isValidFilter,
} from 'ee/admin/data_management/filters';
import { TOKEN_TYPES } from 'ee/admin/data_management/constants';

describe('formatListboxItems', () => {
  it('handles empty array', () => {
    expect(formatListboxItems([])).toStrictEqual([]);
  });

  it('returns formatted items', () => {
    const items = [
      { titlePlural: 'Users', name: 'user' },
      { titlePlural: 'Projects', name: 'project' },
      { titlePlural: 'Issues', name: 'issue' },
    ];

    expect(formatListboxItems(items)).toStrictEqual([
      { text: 'Users', value: 'user' },
      { text: 'Projects', value: 'project' },
      { text: 'Issues', value: 'issue' },
    ]);
  });
});

describe('isValidFilter', () => {
  const validStates = [
    { value: 'verified', text: 'Verified' },
    { value: 'failed', text: 'Failed' },
    { value: 'pending', text: 'Pending' },
  ];

  it.each`
    data          | array          | expected
    ${'verified'} | ${validStates} | ${true}
    ${'invalid'}  | ${validStates} | ${false}
    ${null}       | ${validStates} | ${false}
    ${undefined}  | ${validStates} | ${false}
    ${'verified'} | ${null}        | ${false}
    ${'verified'} | ${undefined}   | ${false}
    ${'verified'} | ${[]}          | ${false}
  `('returns $expected when data is $data and array is $array', ({ data, array, expected }) => {
    expect(isValidFilter(data, array)).toBe(expected);
  });
});

describe('processFilters', () => {
  it.each`
    filters                                                                | query
    ${[]}                                                                  | ${{}}
    ${[{ type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: 'verified' } }]} | ${{ checksum_state: 'verified' }}
    ${['123 456 789']}                                                     | ${{ identifiers: ['123', '456', '789'] }}
  `('returns the correct { query, url } for filters: $filters', ({ filters, query }) => {
    expect(processFilters(filters)).toStrictEqual(query);
  });

  it('handles mixed filter types', () => {
    const filters = ['123 456', { type: TOKEN_TYPES.CHECKSUM_STATE, value: { data: 'verified' } }];

    const expectedQuery = {
      identifiers: ['123', '456'],
      checksum_state: 'verified',
    };

    expect(processFilters(filters)).toStrictEqual(expectedQuery);
  });

  it('handles empty string filters', () => {
    const filters = [''];
    const expectedQuery = {
      identifiers: [''],
    };

    expect(processFilters(filters)).toStrictEqual(expectedQuery);
  });
});
