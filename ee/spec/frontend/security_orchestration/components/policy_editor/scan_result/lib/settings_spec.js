import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  PREVENT_APPROVAL_BY_AUTHOR,
  buildSettingsList,
  mergeRequestConfiguration,
  protectedBranchesConfiguration,
  groupProtectedBranchesConfiguration,
  pushingBranchesConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';

const defaultSettings = buildSettingsList();

describe('buildSettingsList', () => {
  it('returns the default settings', () => {
    expect(buildSettingsList()).toEqual(defaultSettings);
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
      ...groupProtectedBranchesConfiguration,
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
