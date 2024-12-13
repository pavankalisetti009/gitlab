import { s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from '../shared/provider';
import { PRODUCT_ANALYTICS_TAB_METADATA_EL_SELECTOR } from '../constants';
import ProductAnalyticsUsageQuotaApp from './components/product_analytics_usage_quota_app.vue';

const parseProvideData = (el) => {
  const { namespacePath, emptyStateIllustrationPath, productAnalyticsEnabled } = el.dataset;

  return {
    namespacePath,
    emptyStateIllustrationPath,
    productAnalyticsEnabled: parseBoolean(productAnalyticsEnabled),
  };
};

export const getProductAnalyticsTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector(PRODUCT_ANALYTICS_TAB_METADATA_EL_SELECTOR);

  if (!el) return false;

  const productAnalyticsTabMetadata = {
    title: s__('UsageQuota|Product analytics'),
    hash: '#product-analytics-usage-quota-tab',
    testid: 'product-analytics-tab',
    component: {
      name: 'ProductAnalyticsUsageQuotaTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(ProductAnalyticsUsageQuotaApp);
      },
    },
  };

  if (includeEl) {
    productAnalyticsTabMetadata.component.el = el;
  }

  return productAnalyticsTabMetadata;
};
