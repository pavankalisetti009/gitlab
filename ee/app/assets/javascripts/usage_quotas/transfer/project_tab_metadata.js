import ProjectTransferApp from './components/project_transfer_app.vue';
import { getTransferTabMetadata } from './utils';

export const getProjectTransferTabMetadata = () => {
  return getTransferTabMetadata({ vueComponent: ProjectTransferApp });
};
