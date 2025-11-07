<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
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
import MonthlyWaiverCard from './monthly_waiver_card.vue';

export default {
  name: 'UsageBillingApp',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    PageHeading,
    PurchaseCommitmentCard,
    UsageByUserTab,
    CurrentUsageCard,
    CurrentOverageUsageCard,
    MonthlyWaiverCard,
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
    subscriptionsUrl() {
      return gon.subscriptions_url;
    },
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
    monthlyWaiverTotalCredits() {
      return this.subscriptionUsage?.monthlyWaiver?.totalCredits ?? 0;
    },
    monthlyWaiverCreditsUsed() {
      return this.subscriptionUsage?.monthlyWaiver?.creditsUsed ?? 0;
    },
    isMonthlyWaiverAvailable() {
      return Boolean(this.monthlyWaiverTotalCredits);
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

    <gl-alert
      v-if="subscriptionUsage.isOutdatedClient"
      data-testid="outdated-client-alert"
      variant="warning"
      class="gl-my-3"
    >
      <gl-sprintf
        :message="
          s__(
            'UsageBilling|This dashboard may not display all current subscription data. For complete visibility, please upgrade to the latest version of GitLab or visit the %{linkStart}Customer Portal%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="subscriptionsUrl" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
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

        <monthly-waiver-card
          v-if="isMonthlyWaiverAvailable && !overageCreditsUsed"
          :monthly-waiver-total-credits="monthlyWaiverTotalCredits"
          :monthly-waiver-credits-used="monthlyWaiverCreditsUsed"
        />

        <current-overage-usage-card
          v-else-if="overageIsAllowed || overageCreditsUsed"
          :overage-credits-used="overageCreditsUsed"
          :monthly-waiver-credits-used="monthlyWaiverCreditsUsed"
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
