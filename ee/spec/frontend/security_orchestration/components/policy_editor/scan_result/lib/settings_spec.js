import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  buildSettingsList,
  mergeRequestConfiguration,
  protectedBranchesConfiguration,
  pushingBranchesConfiguration,
  createGroupObject,
  groupProtectedBranchesConfiguration,
  organizeGroups,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import { createMockGroup } from 'ee_jest/security_orchestration/mocks/mock_data';

const defaultSettings = buildSettingsList();

describe('buildSettingsList', () => {
  it('returns the default settings with no arguments', () => {
    expect(buildSettingsList()).toEqual(defaultSettings);
  });

  it('returns the default settings when there are no settings', () => {
    expect(
      buildSettingsList({ settings: undefined, options: { namespaceType: NAMESPACE_TYPES.GROUP } }),
    ).toEqual(defaultSettings);
  });

  it('can update merge request settings for projects', () => {
    const settings = {
      ...pushingBranchesConfiguration,
      ...mergeRequestConfiguration,
      [PREVENT_APPROVAL_BY_AUTHOR]: false,
    };
    expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
      ...protectedBranchesConfiguration,
      ...settings,
    });
  });

  it('can update merge request settings for group w/ scanResultPolicyBlockGroupBranchModification ff', () => {
    const settings = {
      ...pushingBranchesConfiguration,
      ...mergeRequestConfiguration,
      [PREVENT_APPROVAL_BY_AUTHOR]: false,
    };
    expect(
      buildSettingsList({
        settings,
        options: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          scanResultPolicyBlockGroupBranchModification: true,
        },
      }),
    ).toEqual({
      ...protectedBranchesConfiguration,
      ...groupProtectedBranchesConfiguration(false),
      ...settings,
    });
  });

  it('can update merge request settings for a group w/ an enabled block_branch_modification setting and w/ scanResultPolicyBlockGroupBranchModification ff', () => {
    const enabledSetting = { [BLOCK_BRANCH_MODIFICATION]: true };
    const settings = {
      ...pushingBranchesConfiguration,
      ...mergeRequestConfiguration,
      [PREVENT_APPROVAL_BY_AUTHOR]: false,
    };
    expect(
      buildSettingsList({
        settings: enabledSetting,
        options: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          scanResultPolicyBlockGroupBranchModification: true,
        },
      }),
    ).toEqual({
      ...enabledSetting,
      ...groupProtectedBranchesConfiguration(true),
      ...settings,
    });
  });

  it('can update merge request settings for SPP w/ linked groups && w/ scanResultPolicyBlockGroupBranchModification ff', () => {
    const settings = {
      ...pushingBranchesConfiguration,
      ...mergeRequestConfiguration,
      [PREVENT_APPROVAL_BY_AUTHOR]: false,
    };
    expect(
      buildSettingsList({
        settings,
        options: {
          hasLinkedGroups: true,
          namespaceType: NAMESPACE_TYPES.PROJECT,
          scanResultPolicyBlockGroupBranchModification: true,
        },
      }),
    ).toEqual({
      ...protectedBranchesConfiguration,
      ...groupProtectedBranchesConfiguration(false),
      ...settings,
    });
  });

  it('can update merge request settings for group w/o scanResultPolicyBlockGroupBranchModification ff', () => {
    const settings = {
      ...pushingBranchesConfiguration,
      ...mergeRequestConfiguration,
      [PREVENT_APPROVAL_BY_AUTHOR]: false,
    };
    expect(
      buildSettingsList({
        settings,
        options: {
          namespaceType: NAMESPACE_TYPES.GROUP,
          scanResultPolicyBlockGroupBranchModification: false,
        },
      }),
    ).toEqual({
      ...protectedBranchesConfiguration,
      ...settings,
    });
  });

  it('has fall back values for settings', () => {
    const settings = {
      [PREVENT_APPROVAL_BY_AUTHOR]: true,
    };

    expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
      ...defaultSettings,
      ...settings,
    });
  });
});

describe('createGroupObject', () => {
  it('creates a group object', () => {
    const group = createMockGroup(1);
    expect(createGroupObject(group)).toEqual({ ...group, text: 'Group-1', value: 1 });
  });
});

describe('organizeGroups', () => {
  const availableGroups = [
    { id: 1, name: 'Group 1' },
    { id: 2, name: 'Group 2' },
    { id: 3, name: 'Group 3' },
  ];

  it('should return empty arrays when no ids are provided', () => {
    const result = organizeGroups({ ids: [], availableGroups: [] });
    expect(result).toEqual({
      existingGroups: [],
      groupsToRetrieve: [],
    });
  });

  it('should correctly separate existing groups and groups to retrieve', () => {
    const ids = [1, 2, 4, 5];

    const result = organizeGroups({ ids, availableGroups });

    expect(result).toEqual({
      existingGroups: [
        { id: 1, name: 'Group 1' },
        { id: 2, name: 'Group 2' },
      ],
      groupsToRetrieve: [4, 5],
    });
  });

  it('should handle all ids not found in available groups', () => {
    const ids = [4, 5];

    const result = organizeGroups({ ids, availableGroups });

    expect(result).toEqual({
      existingGroups: [],
      groupsToRetrieve: [4, 5],
    });
  });

  it('should handle all ids found in available groups', () => {
    const ids = [1, 2, 3];
    const result = organizeGroups({ ids, availableGroups });

    expect(result).toEqual({
      existingGroups: [
        { id: 1, name: 'Group 1' },
        { id: 2, name: 'Group 2' },
        { id: 3, name: 'Group 3' },
      ],
      groupsToRetrieve: [],
    });
  });

  it('should handle undefined parameters using default values', () => {
    const result = organizeGroups({});
    expect(result).toEqual({
      existingGroups: [],
      groupsToRetrieve: [],
    });
  });
});
