import {
  packageForwardingSettings,
  packageSettings,
  dependencyProxySettings,
  dependencyProxyImageTtlPolicy,
  groupPackageSettingsMutationMock,
  groupPackageForwardSettingsMutationMock,
  dependencyProxySettingMutationMock,
  dependencyProxyUpdateTllPolicyMutationMock,
  groupPackageSettingsMutationErrorMock,
  mutationErrorMock,
  npmProps,
  pypiProps,
  mavenProps,
} from 'jest/packages_and_registries/settings/group/mock_data';

export {
  packageForwardingSettings,
  packageSettings,
  dependencyProxySettings,
  dependencyProxyImageTtlPolicy,
  groupPackageSettingsMutationMock,
  groupPackageForwardSettingsMutationMock,
  dependencyProxySettingMutationMock,
  dependencyProxyUpdateTllPolicyMutationMock,
  groupPackageSettingsMutationErrorMock,
  mutationErrorMock,
  npmProps,
  pypiProps,
  mavenProps,
};

export const virtualRegistriesSetting = (extend) => ({
  enabled: true,
  ...extend,
});

export const groupPackageSettingsMock = {
  data: {
    group: {
      id: '1',
      fullPath: 'foo_group_path',
      dependencyProxySetting: dependencyProxySettings(),
      dependencyProxyImageTtlPolicy: dependencyProxyImageTtlPolicy(),
      virtualRegistriesSetting: virtualRegistriesSetting(),
      packageSettings: {
        ...packageSettings,
        __typename: 'PackageSettings',
      },
      __typename: 'Group',
    },
  },
};

export const virtualRegistriesSettingMutationMock = (override) => ({
  data: {
    updateVirtualRegistriesSetting: {
      __typename: 'UpdateVirtualRegistriesSettingPayload',
      virtualRegistriesSetting: {
        __typename: 'VirtualRegistriesSetting',
        ...virtualRegistriesSetting(),
      },
      errors: [],
      ...override,
    },
  },
});
