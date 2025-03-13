import GroupTransferApp from './components/group_transfer_app.vue';
import { getTransferTabMetadata } from './utils';

export const getGroupTransferTabMetadata = () => {
  return getTransferTabMetadata({ vueComponent: GroupTransferApp });
};
