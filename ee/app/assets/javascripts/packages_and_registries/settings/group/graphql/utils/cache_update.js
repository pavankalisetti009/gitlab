import { produce } from 'immer';
import getGroupPackagesSettingsQuery from '~/packages_and_registries/settings/group/graphql/queries/get_group_packages_settings.query.graphql';

export const updateGroupPackageSettings =
  (fullPath) =>
  (client, { data: updatedData }) => {
    const queryAndParams = {
      query: getGroupPackagesSettingsQuery,
      variables: { fullPath },
    };

    const sourceData = client.readQuery(queryAndParams);

    if (!sourceData?.group?.virtualRegistriesSetting) {
      return;
    }

    const data = produce(sourceData, (draftState) => {
      Object.assign(
        draftState.group.virtualRegistriesSetting,
        updatedData.updateVirtualRegistriesSetting?.virtualRegistriesSetting || {},
      );
    });

    client.writeQuery({
      ...queryAndParams,
      data,
    });
  };
