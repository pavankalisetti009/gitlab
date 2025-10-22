<script>
import { GlAlert, GlAvatar, GlCard, GlLoadingIcon } from '@gitlab/ui';
import UserDate from '~/vue_shared/components/user_date.vue';
import { mockDataWithPool } from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import EventsTable from './events_table.vue';

export default {
  name: 'UsageBillingUserDashboardApp',
  components: {
    GlCard,
    GlLoadingIcon,
    GlAlert,
    GlAvatar,
    UserDate,
    HumanTimeframe,
    EventsTable,
  },
  inject: ['userId', 'fetchUserUsageDataApiUrl'],
  data() {
    return {
      isError: false,
      isLoading: true,
      gitlabCreditsUsage: null,
    };
  },
  computed: {
    userUsage() {
      return this.gitlabCreditsUsage.userUsage;
    },
    user() {
      return this.userUsage.user;
    },
    hasCommitment() {
      return Boolean(this.gitlabCreditsUsage?.totalCredits);
    },
  },
  async mounted() {
    await this.fetchUsageData();
  },
  methods: {
    async fetchUsageData() {
      try {
        this.isLoading = true;
        const response = await axios.get(this.fetchUserUsageDataApiUrl);
        this.gitlabCreditsUsage = response?.data?.subscription?.gitlabCreditsUsage;
      } catch (error) {
        this.isError = true;
        logError(error);
        captureException(error);

        // TODO: this fallback will be removed once we integrate with actual BE
        this.gitlabCreditsUsage = mockDataWithPool.subscription.gitlabCreditsUsage;
      } finally {
        this.isLoading = false;
      }
    },
  },
  SHORT_DATE_FORMAT_WITH_TIME,
};
</script>
<template>
  <section>
    <gl-alert v-if="isError" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <div v-if="isLoading">
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
              :src="user.avatar_url"
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
            :date="gitlabCreditsUsage.lastUpdated"
            :date-format="$options.SHORT_DATE_FORMAT_WITH_TIME"
          />
        </div>
      </header>

      <dl class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
        <gl-card data-testid="month-summary-card" class="gl-flex-1 gl-bg-transparent">
          <dd class="gl-heading-scale-400 gl-mb-3">
            {{ userUsage.allocationUsed }} / {{ userUsage.allocationTotal }}
          </dd>
          <dt>
            <p class="gl-my-0">
              {{ s__('UsageBilling|Credits used this month') }}
            </p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabCreditsUsage.startDate"
                :till="gitlabCreditsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>

        <gl-card
          v-if="hasCommitment"
          data-testid="month-pool-card"
          class="gl-flex-1 gl-bg-transparent"
        >
          <dd class="gl-heading-scale-400 gl-mb-3">{{ userUsage.poolUsed }}</dd>
          <dt>
            <p class="gl-my-0">{{ s__('UsageBilling|Credits used from pool this month') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabCreditsUsage.startDate"
                :till="gitlabCreditsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>

        <gl-card data-testid="total-usage-card" class="gl-flex-1 gl-bg-transparent">
          <dd class="gl-heading-scale-400 gl-mb-3">
            {{ userUsage.totalCreditsUsed }}
          </dd>
          <dt>
            <p class="gl-my-0">{{ s__('UsageBilling|Total credits used') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabCreditsUsage.startDate"
                :till="gitlabCreditsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>
      </dl>

      <events-table :events="userUsage.events" />
    </template>
  </section>
</template>
