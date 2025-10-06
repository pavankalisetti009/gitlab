<script>
import { GlAlert, GlTab, GlTabs } from '@gitlab/ui';
import { mockUsageDataWithPool } from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageTrendsChart from './usage_trends_chart.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import CurrentUsageCard from './current_usage_card.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    GlTabs,
    GlTab,
    PageHeading,
    PurchaseCommitmentCard,
    UsageTrendsChart,
    UsageByUserTab,
    CurrentUsageCard,
  },
  inject: ['fetchUsageDataApiUrl'],
  data() {
    return {
      isLoading: true,
      isError: false,
      subscriptionData: null,
    };
  },
  computed: {
    gitlabCreditsUsage() {
      return this.subscriptionData.gitlabCreditsUsage;
    },
    hasCommitment() {
      return Boolean(this.gitlabCreditsUsage?.totalCredits);
    },
    trend() {
      return (
        this.gitlabCreditsUsage.poolUsage?.usageTrend ||
        this.gitlabCreditsUsage.seatUsage?.usageTrend
      );
    },
    dailyUsage() {
      return (
        this.gitlabCreditsUsage.poolUsage?.dailyUsage ||
        this.gitlabCreditsUsage.seatUsage?.dailyUsage
      );
    },
    dailyPeak() {
      return (
        this.gitlabCreditsUsage.poolUsage?.peakUsage || this.gitlabCreditsUsage.seatUsage?.peakUsage
      );
    },
    dailyAverage() {
      return (
        this.gitlabCreditsUsage.poolUsage?.dailyAverage ||
        this.gitlabCreditsUsage.seatUsage?.dailyAverage
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
        const response = await axios.get(this.fetchUsageDataApiUrl);
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

    <gl-alert v-if="isError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <div v-if="isLoading" data-testid="skeleton-loaders">
      <section class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
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
      <section class="gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
        <current-usage-card
          v-if="hasCommitment"
          :total-credits="gitlabCreditsUsage.totalCredits"
          :total-credits-used="gitlabCreditsUsage.totalCreditsUsed"
          :current-overage="gitlabCreditsUsage.overageCredits"
          :month-start-date="gitlabCreditsUsage.startDate"
          :month-end-date="gitlabCreditsUsage.endDate"
        />

        <purchase-commitment-card :has-commitment="hasCommitment" />
      </section>
      <gl-tabs class="gl-mt-5" lazy>
        <gl-tab :title="s__('UsageBilling|Usage trends')">
          <usage-trends-chart
            :usage-data="dailyUsage"
            :month-start-date="gitlabCreditsUsage.startDate"
            :month-end-date="gitlabCreditsUsage.endDate"
            :trend="trend"
            :daily-peak="dailyPeak"
            :daily-average="dailyAverage"
            :threshold="gitlabCreditsUsage.totalCredits"
          />
        </gl-tab>
        <gl-tab :title="s__('UsageBilling|Usage by user')">
          <usage-by-user-tab :has-commitment="hasCommitment" />
        </gl-tab>
      </gl-tabs>
    </template>
  </section>
</template>
