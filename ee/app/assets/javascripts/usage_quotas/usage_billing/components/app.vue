<script>
import { GlAlert, GlTab, GlTabs } from '@gitlab/ui';
import { mockUsageDataWithPool } from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageTrendsChart from './usage_trends_chart.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import CurrentUsageCard from './current_usage_card.vue';
import CurrentUsageNoPoolCard from './current_usage_no_pool_card.vue';

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
    CurrentUsageNoPoolCard,
  },
  apollo: {
    subscriptionUsage: {
      query: getSubscriptionUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
        };
      },
      update({ subscriptionUsage }) {
        // NOTE: this is a temporary injection to stub `overage` field.
        // This should be removed once the field is added in https://gitlab.com/gitlab-org/gitlab/-/issues/567987
        if (subscriptionUsage) {
          // eslint-disable-next-line no-param-reassign
          subscriptionUsage = {
            ...subscriptionUsage,
            overage: {
              isAllowed: true,
              creditsUsed: 0,
            },
          };
        }

        return subscriptionUsage;
      },
      error(error) {
        logError(error);
        captureException(error);
        this.isError = true;
      },
    },
  },
  inject: {
    fetchUsageDataApiUrl: { default: '' },
    namespacePath: { default: '' },
  },
  data() {
    return {
      isFetchingData: true,
      isError: false,
      subscriptionData: null,
      subscriptionUsage: {},
    };
  },
  computed: {
    poolIsAvailable() {
      return Boolean(this.poolTotalCredits);
    },
    poolCreditsUsed() {
      return this.subscriptionUsage?.poolUsage?.creditsUsed ?? 0;
    },
    poolTotalCredits() {
      return this.subscriptionUsage?.poolUsage?.totalCredits ?? 0;
    },
    overageIsAllowed() {
      return Boolean(this.subscriptionUsage?.overage?.isAllowed);
    },
    overageCreditsUsed() {
      return this.subscriptionUsage?.overage?.creditsUsed ?? 0;
    },
    gitlabCreditsUsage() {
      return this.subscriptionData.gitlabCreditsUsage;
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
    isLoading() {
      return this.isFetchingData || this.$apollo.queries.subscriptionUsage.loading;
    },
  },
  async mounted() {
    await this.fetchUsageData();
  },
  methods: {
    async fetchUsageData() {
      try {
        this.isFetchingData = true;
        const response = await axios.get(this.fetchUsageDataApiUrl);
        this.subscriptionData = response?.data?.subscription;
      } catch (error) {
        this.isError = true;
        logError(error);
        captureException(error);

        // TODO: this fallback will be removed once we integrate with actual BE
        this.subscriptionData = mockUsageDataWithPool.subscription;
      } finally {
        this.isFetchingData = false;
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
          v-if="poolIsAvailable"
          :pool-total-credits="poolTotalCredits"
          :pool-credits-used="poolCreditsUsed"
          :overage-credits-used="overageCreditsUsed"
          :month-start-date="gitlabCreditsUsage.startDate"
          :month-end-date="gitlabCreditsUsage.endDate"
        />

        <current-usage-no-pool-card
          v-else-if="overageIsAllowed"
          :overage-credits-used="overageCreditsUsed"
          :month-start-date="gitlabCreditsUsage.startDate"
          :month-end-date="gitlabCreditsUsage.endDate"
        />

        <purchase-commitment-card :has-commitment="poolIsAvailable" />
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
            :threshold="poolTotalCredits"
          />
        </gl-tab>
        <gl-tab :title="s__('UsageBilling|Usage by user')">
          <usage-by-user-tab :has-commitment="poolIsAvailable" />
        </gl-tab>
      </gl-tabs>
    </template>
  </section>
</template>
