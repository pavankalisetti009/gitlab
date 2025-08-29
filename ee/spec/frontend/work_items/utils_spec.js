import { getStatuses } from 'ee/work_items/utils';
import { namespaceWorkItemTypesQueryResponse } from 'jest/work_items/mock_data';

describe('getStatuses', () => {
  it('merges, sorts, and deduplicates statuses', () => {
    expect(
      getStatuses(namespaceWorkItemTypesQueryResponse.data.workspace.workItemTypes.nodes),
    ).toEqual([
      expect.objectContaining({ name: 'To do' }),
      expect.objectContaining({ name: 'In progress' }),
      expect.objectContaining({ name: 'In dev' }),
      expect.objectContaining({ name: 'In review' }),
      expect.objectContaining({ name: 'Done' }),
      expect.objectContaining({ name: 'Complete' }),
      expect.objectContaining({ name: "Won't do" }),
      expect.objectContaining({ name: 'Duplicate' }),
    ]);
  });
});
