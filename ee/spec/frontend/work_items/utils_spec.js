import { getDefaultStateType, getStatuses, sortStatuses } from 'ee/work_items/utils';
import { namespaceWorkItemTypesQueryResponse } from 'jest/work_items/mock_data';

describe('getDefaultStateType', () => {
  const mockLifecycle = {
    defaultClosedStatus: { id: 'closed-id' },
    defaultDuplicateStatus: { id: 'duplicate-id' },
    defaultOpenStatus: { id: 'open-id' },
  };

  it('returns DEFAULT_STATE_CLOSED if status matches defaultClosedStatus', () => {
    const status = { id: 'closed-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('closed');
  });

  it('returns DEFAULT_STATE_DUPLICATE if status matches defaultDuplicateStatus', () => {
    const status = { id: 'duplicate-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('duplicate');
  });

  it('returns DEFAULT_STATE_OPEN if status matches defaultOpenStatus', () => {
    const status = { id: 'open-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('open');
  });

  it('returns null if status does not match any default status', () => {
    const status = { id: 'some-other-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBeNull();
  });
});

describe('sortStatuses', () => {
  it('sorts, and deduplicates statuses', () => {
    const statuses = [
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
        category: 'to_do',
        name: 'To do',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/2',
        category: 'in_progress',
        name: 'In progress',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/3',
        category: 'done',
        name: 'Done',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/4',
        category: 'canceled',
        name: "Won't do",
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/5',
        category: 'canceled',
        name: 'Duplicate',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
        category: 'to_do',
        name: 'To do',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/7',
        category: 'in_progress',
        name: 'In dev',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/8',
        category: 'in_progress',
        name: 'In review',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/9',
        category: 'done',
        name: 'Complete',
      },
    ];

    expect(sortStatuses(statuses)).toEqual([
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

describe('getStatuses', () => {
  it('merges, sorts, and deduplicates statuses', () => {
    expect(
      getStatuses(namespaceWorkItemTypesQueryResponse.data.namespace.workItemTypes.nodes),
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
