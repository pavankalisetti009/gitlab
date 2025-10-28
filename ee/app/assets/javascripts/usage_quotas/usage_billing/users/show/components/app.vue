<script>
import { GlKeysetPagination, GlAlert, GlAvatar, GlCard, GlLoadingIcon } from '@gitlab/ui';
import UserDate from '~/vue_shared/components/user_date.vue';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { PAGE_SIZE } from '../../../constants';
import getUserSubscriptionUsageQuery from '../graphql/get_user_subscription_usage.query.graphql';
import EventsTable from './events_table.vue';

export default {
  name: 'UsageBillingUserDashboardApp',
  components: {
    GlCard,
    GlLoadingIcon,
    GlAlert,
    GlAvatar,
    GlKeysetPagination,
    UserDate,
    HumanTimeframe,
    EventsTable,
  },
  inject: {
    username: 'username',
    namespacePath: {
      default: null,
    },
  },
  data() {
    return {
      isError: false,
      subscriptionUsage: null,
      pagination: {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      },
    };
  },
  apollo: {
    subscriptionUsage: {
      query: getUserSubscriptionUsageQuery,
      variables() {
        return {
          // Note: namespacePath will be present on SaaS only, indicating a root group.
          // SM would pass null in this variable, requesting instance-level data.
          namespacePath: this.namespacePath,
          username: this.username,
          first: this.pagination.first,
          last: this.pagination.last,
          after: this.pagination.after,
          before: this.pagination.before,
        };
      },
      error(error) {
        this.isError = true;
        logError(error);
        captureException(error);
      },
      update(data) {
        return data.subscriptionUsage;
      },
    },
  },
  computed: {
    user() {
      return this.subscriptionUsage?.usersUsage?.users?.nodes?.[0];
    },
    usage() {
      const {
        creditsUsed = 0,
        totalCredits = 0,
        monthlyCommitmentCreditsUsed = 0,
        oneTimeCreditsUsed = 0,
        overageCreditsUsed = 0,
      } = this.user?.usage ?? {};

      return {
        creditsUsed,
        totalCredits,
        monthlyCommitmentCreditsUsed,
        oneTimeCreditsUsed,
        overageCreditsUsed,
      };
    },
    totalCreditsUsed() {
      return (
        this.usage.creditsUsed +
        this.usage.monthlyCommitmentCreditsUsed +
        this.usage.oneTimeCreditsUsed +
        this.usage.overageCreditsUsed
      );
    },
    events() {
      return this.user?.events?.nodes ?? [];
    },
    pageInfo() {
      return this.user?.events?.pageInfo;
    },
  },
  methods: {
    numberToMetricPrefix,
    onNextPage(item) {
      this.pagination = {
        first: PAGE_SIZE,
        after: item,
        last: null,
        before: null,
      };
    },
    onPrevPage(item) {
      this.pagination = {
        first: null,
        after: null,
        last: PAGE_SIZE,
        before: item,
      };
    },
  },
  SHORT_DATE_FORMAT_WITH_TIME,
};
</script>
<template>
  <section>
    <gl-alert v-if="isError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <div v-else-if="$apollo.queries.subscriptionUsage.loading">
      <gl-loading-icon />
    </div>

    <template v-else>
      <header class="gl-my-5 gl-flex gl-flex-col gl-gap-3">
        <div
          class="gl-mb-2 gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-3 @md/panel:gl-flex-row"
        >
          <div class="gl-flex gl-items-center">
            <gl-avatar
              :title="user.name"
              :alt="user.name"
              :src="user.avatarUrl"
              :entity-name="user.name"
              :size="64"
              class="gl-mr-3"
            />

            <div>
              <h1 class="gl-heading-1 gl-my-0">{{ user.name }}</h1>
              <p class="gl-my-0 gl-font-bold gl-text-subtle">@{{ user.username }}</p>
            </div>
          </div>
        </div>

        <div class="gl-text-sm gl-text-subtle">
          {{ s__('UsageBilling|Last updated:') }}
          <user-date
            :date="subscriptionUsage.lastEventTransactionAt"
            :date-format="$options.SHORT_DATE_FORMAT_WITH_TIME"
          />
        </div>
      </header>

      <div class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
        <gl-card
          data-testid="included-credits-card"
          class="gl-flex-1 gl-bg-transparent"
          body-class="gl-p-5"
        >
          <div
            class="gl-heading-scale-600 gl-mb-3 gl-font-bold"
            data-testid="included-credits-card-value"
          >
            {{ numberToMetricPrefix(usage.creditsUsed) }}
            <span class="gl-heading-scale-600 gl-font-bold gl-text-subtle">
              / {{ numberToMetricPrefix(usage.totalCredits) }}
            </span>
          </div>
          <div class="gl-font-bold">
            <p class="gl-my-0">
              {{ s__('UsageBillingUserDetails|included credits used this month') }}
            </p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              <human-timeframe
                :from="subscriptionUsage.startDate"
                :till="subscriptionUsage.endDate"
              />
            </p>
          </div>
        </gl-card>

        <gl-card
          data-testid="total-usage-card"
          class="gl-flex-1 gl-bg-transparent"
          body-class="gl-p-5"
        >
          <div class="gl-heading-scale-600 gl-mb-3 gl-font-bold">
            {{ numberToMetricPrefix(totalCreditsUsed) }}
          </div>
          <div class="gl-font-bold">
            <p class="gl-my-0">{{ s__('UsageBillingUserDetails|total credits used') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              <human-timeframe
                :from="subscriptionUsage.startDate"
                :till="subscriptionUsage.endDate"
              />
            </p>
          </div>
        </gl-card>
      </div>

      <section>
        <events-table :events="events" />

        <div v-if="pageInfo" class="gl-mt-5 gl-flex gl-justify-center">
          <gl-keyset-pagination v-bind="pageInfo" @prev="onPrevPage" @next="onNextPage" />
        </div>
      </section>
    </template>
  </section>
</template>
