import { getNamespaceStorageTabMetadata } from '~/usage_quotas/storage/namespace/tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getPipelineTabMetadata } from './pipelines/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getPipelineTabMetadata(),
  getNamespaceStorageTabMetadata(),
  getPagesTabMetadata(),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
