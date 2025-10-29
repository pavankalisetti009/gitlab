import { mutationErrorMock } from 'jest/packages_and_registries/settings/group/mock_data';

export { mutationErrorMock };

export const virtualRegistriesSetting = (extend) => ({
  enabled: true,
  ...extend,
});

export const groupVirtualRegistriesSettingMock = {
  data: {
    group: {
      id: '1',
      fullPath: 'foo_group_path',
      virtualRegistriesSetting: virtualRegistriesSetting(),
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
