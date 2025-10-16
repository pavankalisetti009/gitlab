import { formatListboxItems, processFilters } from 'ee/admin/data_management/filters';
import { TEST_HOST } from 'spec/test_constants';
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

describe('processFilters', () => {
  const url = new URL(TEST_HOST);

  it.each`
    filters                                          | query
    ${[]}                                            | ${{}}
    ${[{ type: TOKEN_TYPES.MODEL, value: 'model' }]} | ${{ model_name: 'model' }}
  `('returns the correct { query, url }', ({ filters, query }) => {
    expect(processFilters(filters)).toStrictEqual({ query, url });
  });
});
