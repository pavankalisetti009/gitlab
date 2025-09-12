<script>
import { GlAlert, GlCard, GlTab, GlTabs } from '@gitlab/ui';
import { mockUsageDataWithPool } from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageTrendsChart from './usage_trends_chart.vue';
import UsageByUserTab from './usage_by_user_tab.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    GlCard,
    GlTabs,
    GlTab,
    PageHeading,
    PurchaseCommitmentCard,
    UsageTrendsChart,
    UsageByUserTab,
  },
  data() {
    return {
      isLoading: true,
      isError: false,
      subscriptionData: null,
    };
  },
  computed: {
    gitlabUnitsUsage() {
      return this.subscriptionData.gitlabUnitsUsage;
    },
    trend() {
      return (
        this.gitlabUnitsUsage.poolUsage?.usageTrend || this.gitlabUnitsUsage.seatUsage?.usageTrend
      );
    },
    dailyUsage() {
      return (
        this.gitlabUnitsUsage.poolUsage?.dailyUsage || this.gitlabUnitsUsage.seatUsage?.dailyUsage
      );
    },
    dailyPeak() {
      return (
        this.gitlabUnitsUsage.poolUsage?.peakUsage || this.gitlabUnitsUsage.seatUsage?.peakUsage
      );
    },
    dailyAverage() {
      return (
        this.gitlabUnitsUsage.poolUsage?.dailyAverage ||
        this.gitlabUnitsUsage.seatUsage?.dailyAverage
      );
    },
  },
  async mounted() {
    await this.fetchUsageData();
  },
  methods: {
    async fetchUsageData() {
      try {
        this.isLoading = true;
        // TODO: this URL should be configurable
        const response = await axios.get('/admin/gitlab_duo/usage/data');
        this.subscriptionData = response?.data?.subscription;
      } catch (error) {
        this.isError = true;
        logError(error);
        captureException(error);

        // TODO: this fallback will be removed once we integrate with actual BE
        this.subscriptionData = mockUsageDataWithPool.subscription;
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
<template>
  <section>
    <page-heading>
      <template #heading>
        <span data-testid="usage-billing-title">{{ s__('UsageBilling|Usage Billing') }}</span>
      </template>
    </page-heading>

    <gl-alert v-if="isError" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <div v-if="isLoading" data-testid="skeleton-loaders">
      <section class="gl-my-5 gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>

        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>
      </section>

      <div class="gl-mt-15 gl-flex gl-flex-col gl-gap-3">
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
        <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      </div>
    </div>
    <template v-else>
      <section class="gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
        <gl-card class="gl-flex-1 gl-bg-transparent">
          <h2 class="gl-font-heading gl-heading-scale-400 gl-mb-3">
            {{ s__('UsageBilling|Current month usage') }}
          </h2>
        </gl-card>

        <purchase-commitment-card />
      </section>
      <gl-tabs class="gl-mt-5">
        <gl-tab :title="s__('UsageBilling|Usage trends')">
          <usage-trends-chart
            :usage-data="dailyUsage"
            :month-start-date="gitlabUnitsUsage.startDate"
            :month-end-date="gitlabUnitsUsage.endDate"
            :trend="trend"
            :daily-peak="dailyPeak"
            :daily-average="dailyAverage"
          />
        </gl-tab>
        <gl-tab :title="s__('UsageBilling|Usage by user')">
          <usage-by-user-tab :users-data="gitlabUnitsUsage.usersUsage" />
        </gl-tab>
      </gl-tabs>

      <pre>{{ JSON.stringify(subscriptionData, null, 2) }}</pre>
    </template>
  </section>
</template>
