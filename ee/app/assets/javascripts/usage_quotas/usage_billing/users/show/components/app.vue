<script>
import { GlAlert, GlAvatar, GlButton, GlCard, GlLoadingIcon } from '@gitlab/ui';
import UserDate from '~/vue_shared/components/user_date.vue';
import { mockData } from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
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
    GlButton,
    UserDate,
    HumanTimeframe,
    EventsTable,
  },
  inject: ['userId'],
  data() {
    return {
      isError: false,
      isLoading: true,
      gitlabUnitsUsage: null,
    };
  },
  computed: {
    userUsage() {
      return this.gitlabUnitsUsage.userUsage;
    },
    user() {
      return this.userUsage.user;
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
        const response = await axios.get(`/admin/gitlab_duo/usage/users/${this.userId}/data`);
        this.gitlabUnitsUsage = response?.data?.subscription?.gitlabUnitsUsage;
      } catch (error) {
        this.isError = true;
        logError(error);
        captureException(error);

        // TODO: this fallback will be removed once we integrate with actual BE
        this.gitlabUnitsUsage = mockData.subscription.gitlabUnitsUsage;
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
          class="gl-mb-2 gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-3 md:gl-flex-row"
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
              <p class="gl-my-0 gl-text-subtle">@{{ user.username }}</p>
            </div>
          </div>

          <div>
            <gl-button
              category="secondary"
              variant="default"
              data-testid="export-usage-data-button"
              >{{ s__('UsageBilling|Export usage data') }}</gl-button
            >
          </div>
        </div>

        <div class="gl-text-sm gl-text-subtle">
          {{ s__('UsageBilling|Last updated:') }}
          <user-date
            :date="gitlabUnitsUsage.lastUpdated"
            :date-format="$options.SHORT_DATE_FORMAT_WITH_TIME"
          />
        </div>
      </header>

      <dl class="gl-my-5 gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
        <gl-card data-testid="month-summary-card" class="gl-flex-1 gl-bg-transparent">
          <dd class="gl-font-heading gl-heading-scale-400 gl-mb-3">
            {{ userUsage.allocationUsed }} / {{ userUsage.allocationTotal }}
          </dd>
          <dt>
            <p class="gl-my-0">
              {{ s__('UsageBilling|Units used this month') }}
            </p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabUnitsUsage.startDate"
                :till="gitlabUnitsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>

        <gl-card data-testid="month-pool-card" class="gl-flex-1 gl-bg-transparent">
          <dd class="gl-font-heading gl-heading-scale-400 gl-mb-3">{{ userUsage.poolUsed }}</dd>
          <dt>
            <p class="gl-my-0">{{ s__('UsageBilling|Units used from pool this month') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabUnitsUsage.startDate"
                :till="gitlabUnitsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>

        <gl-card data-testid="total-usage-card" class="gl-flex-1 gl-bg-transparent">
          <dd class="gl-font-heading gl-heading-scale-400 gl-mb-3">
            {{ userUsage.totalUnitsUsed }}
          </dd>
          <dt>
            <p class="gl-my-0">{{ s__('UsageBilling|Total units used') }}</p>
            <p class="gl-my-0 gl-text-sm gl-text-subtle">
              (<human-timeframe
                :from="gitlabUnitsUsage.startDate"
                :till="gitlabUnitsUsage.endDate"
              />)
            </p>
          </dt>
        </gl-card>
      </dl>

      <events-table :events="userUsage.events" />
    </template>
  </section>
</template>
