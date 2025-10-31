<script>
import { GlAlert } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import getSubscriptionUsageQuery from '../graphql/get_subscription_usage.query.graphql';
import PurchaseCommitmentCard from './purchase_commitment_card.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import CurrentUsageCard from './current_usage_card.vue';
import CurrentOverageUsageCard from './current_overage_usage_card.vue';
import OneTimeCreditsCard from './one_time_credits_card.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    PageHeading,
    PurchaseCommitmentCard,
    UsageByUserTab,
    CurrentUsageCard,
    CurrentOverageUsageCard,
    OneTimeCreditsCard,
    UserDate,
    HumanTimeframe,
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
    namespacePath: { default: '' },
  },
  data() {
    return {
      isError: false,
      subscriptionUsage: {},
    };
  },
  computed: {
    poolIsAvailable() {
      return Boolean(this.poolTotalCredits);
    },
    poolCreditsUsed() {
      return this.subscriptionUsage?.monthlyCommitment?.creditsUsed ?? 0;
    },
    poolTotalCredits() {
      return this.subscriptionUsage?.monthlyCommitment?.totalCredits ?? 0;
    },
    overageIsAllowed() {
      return Boolean(this.subscriptionUsage?.overage?.isAllowed);
    },
    overageCreditsUsed() {
      return this.subscriptionUsage?.overage?.creditsUsed ?? 0;
    },
    isLoading() {
      return this.$apollo.queries.subscriptionUsage.loading;
    },
    otcCreditsUsed() {
      return this.subscriptionUsage?.oneTimeCredits?.creditsUsed;
    },
    otcRemainingCredits() {
      return this.subscriptionUsage?.oneTimeCredits?.totalCreditsRemaining;
    },
    otcIsAvailable() {
      return Boolean(this.otcCreditsUsed || this.otcRemainingCredits);
    },
    monthEndDate() {
      return this.subscriptionUsage?.endDate;
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
      <template #description>
        <div
          v-if="subscriptionUsage.startDate && subscriptionUsage.endDate"
          class="gl-text-default"
        >
          <span class="gl-font-bold">
            {{ s__('UsageBilling|Billing period:') }}
          </span>
          <human-timeframe :from="subscriptionUsage.startDate" :till="subscriptionUsage.endDate" />
        </div>
        <div v-if="subscriptionUsage.lastEventTransactionAt">
          {{ s__('UsageBilling|Last event transaction at:') }}
          <user-date
            :date="subscriptionUsage.lastEventTransactionAt"
            :date-format="$options.LONG_DATE_FORMAT_WITH_TZ"
          />
        </div>
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
          :month-end-date="monthEndDate"
        />

        <one-time-credits-card
          v-if="otcIsAvailable && !overageCreditsUsed"
          :otc-credits-used="otcCreditsUsed"
          :otc-remaining-credits="otcRemainingCredits"
        />

        <current-overage-usage-card
          v-else-if="overageIsAllowed || overageCreditsUsed"
          :overage-credits-used="overageCreditsUsed"
          :otc-credits-used="otcCreditsUsed"
          :month-end-date="monthEndDate"
        />

        <purchase-commitment-card
          v-if="subscriptionUsage.purchaseCreditsPath"
          :has-commitment="poolIsAvailable"
          :purchase-credits-path="subscriptionUsage.purchaseCreditsPath"
        />
      </section>
      <usage-by-user-tab />
    </template>
  </section>
</template>
