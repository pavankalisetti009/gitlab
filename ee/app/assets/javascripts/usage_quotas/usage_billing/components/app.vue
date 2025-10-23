<script>
import { GlAlert } from '@gitlab/ui';
import { mockUsageDataWithPool } from 'ee_jest/usage_quotas/usage_billing/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import CurrentUsageCard from './current_usage_card.vue';
import CurrentOverageUsageCard from './current_overage_usage_card.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    PageHeading,
    PurchaseCommitmentCard,
    UsageByUserTab,
    CurrentUsageCard,
    CurrentOverageUsageCard,
    UserDate,
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
  LONG_DATE_FORMAT_WITH_TZ,
};
</script>
<template>
  <section>
    <page-heading>
      <template #heading>
        <span data-testid="usage-billing-title">{{ s__('UsageBilling|Usage Billing') }}</span>
      </template>
      <template v-if="subscriptionUsage.lastEventTransactionAt" #description>
        {{ s__('UsageBilling|Last updated:') }}
        <user-date
          :date="subscriptionUsage.lastEventTransactionAt"
          :date-format="$options.LONG_DATE_FORMAT_WITH_TZ"
        />
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
          :month-start-date="gitlabCreditsUsage.startDate"
          :month-end-date="gitlabCreditsUsage.endDate"
        />

        <current-overage-usage-card
          v-if="overageIsAllowed"
          :overage-credits-used="overageCreditsUsed"
          :month-start-date="gitlabCreditsUsage.startDate"
          :month-end-date="gitlabCreditsUsage.endDate"
        />

        <purchase-commitment-card
          v-if="subscriptionUsage.purchaseCreditsPath"
          :has-commitment="poolIsAvailable"
          :purchase-credits-path="subscriptionUsage.purchaseCreditsPath"
        />
      </section>
      <usage-by-user-tab :has-commitment="poolIsAvailable" />
    </template>
  </section>
</template>
