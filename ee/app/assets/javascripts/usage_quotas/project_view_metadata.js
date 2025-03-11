import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import { getProjectStorageTabMetadata } from '~/usage_quotas/storage/project/tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getTransferTabMetadata } from './transfer/tab_metadata';
import { getObservabilityTabMetadata } from './observability/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getProjectStorageTabMetadata(),
  getTransferTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
  getObservabilityTabMetadata(),
  getPagesTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
