import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import { getStorageTabMetadata } from '~/usage_quotas/storage/tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getTransferTabMetadata } from './transfer/tab_metadata';
import { getObservabilityTabMetadata } from './observability/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getStorageTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
  getTransferTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
  getObservabilityTabMetadata(),
  getPagesTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
