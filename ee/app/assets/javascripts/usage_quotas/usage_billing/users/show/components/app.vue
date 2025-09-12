<script>
import { GlAlert, GlLoadingIcon, GlAvatar, GlButton } from '@gitlab/ui';
import UserDate from '~/vue_shared/components/user_date.vue';
import { mockData } from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';

export default {
  name: 'UsageBillingUserDashboardApp',
  components: {
    GlLoadingIcon,
    GlAlert,
    GlAvatar,
    GlButton,
    UserDate,
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
      <!-- Header with user details -->
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
    </template>
  </section>
</template>
