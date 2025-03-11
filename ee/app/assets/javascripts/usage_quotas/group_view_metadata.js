import customApolloProvider from 'ee/usage_quotas/shared/provider';
import { getNamespaceStorageTabMetadata } from '~/usage_quotas/storage/namespace/tab_metadata';
import { GROUP_VIEW_TYPE } from '~/usage_quotas/constants';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getSeatTabMetadata } from './seats/tab_metadata';
import { getCodeSuggestionsTabMetadata } from './code_suggestions/tab_metadata';
import { getPipelineTabMetadata } from './pipelines/tab_metadata';
import { getTransferTabMetadata } from './transfer/tab_metadata';
import { getProductAnalyticsTabMetadata } from './product_analytics/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getSeatTabMetadata(),
  getCodeSuggestionsTabMetadata(),
  getPipelineTabMetadata(),
  getNamespaceStorageTabMetadata({ customApolloProvider }),
  getTransferTabMetadata({ viewType: GROUP_VIEW_TYPE }),
  getProductAnalyticsTabMetadata(),
  getPagesTabMetadata(),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
