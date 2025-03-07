import { PROFILE_VIEW_TYPE } from '~/usage_quotas/constants';
import { getStorageTabMetadata } from '~/usage_quotas/storage/tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getPipelineTabMetadata } from './pipelines/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getPipelineTabMetadata(),
  getStorageTabMetadata({ viewType: PROFILE_VIEW_TYPE }),
  getPagesTabMetadata(),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
