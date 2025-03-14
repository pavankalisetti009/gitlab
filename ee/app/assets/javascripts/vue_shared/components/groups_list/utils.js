import {
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/vue_shared/components/groups_list/utils';
import toast from '~/vue_shared/plugins/global_toast';
import { sprintf, __ } from '~/locale';

// Exports override for EE
// eslint-disable-next-line import/export
export * from '~/vue_shared/components/groups_list/utils';

// Exports override for EE
// eslint-disable-next-line import/export
export const renderDeleteSuccessToast = (item) => {
  // If delayed deletion is disabled or the project/group is already marked for deletion, use the CE toast
  if (!item.isAdjournedDeletionEnabled || item.markedForDeletionOn) {
    renderDeleteSuccessToastCE(item);
    return;
  }

  toast(
    sprintf(__("Group '%{group_name}' will be deleted on %{date}."), {
      group_name: item.fullName,
      date: item.permanentDeletionDate,
    }),
  );
};

// Exports override for EE
// eslint-disable-next-line import/export
export const deleteParams = (item) => {
  // If delayed deletion is disabled or the project/group is not yet marked for deletion, use the CE params
  if (!item.isAdjournedDeletionEnabled || !item.markedForDeletionOn) {
    return deleteParamsCE();
  }

  return { permanently_remove: true };
};
