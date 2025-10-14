import { formatListboxItems } from 'ee/admin/data_management/filters';

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
