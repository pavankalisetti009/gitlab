<script>
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import axios from '~/lib/utils/axios_utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { mockData } from 'ee_jest/usage_quotas/usage_billing/users/show/mock_data';

export default {
  name: 'UsageBillingUserDashboardApp',
  components: {
    GlLoadingIcon,
    GlAlert,
  },
  inject: ['userId'],
  data() {
    return {
      isError: false,
      isLoading: true,
      gitlabUnitsUsage: null,
    };
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
      <pre>{{ JSON.stringify(gitlabUnitsUsage, null, 2) }}</pre>
    </template>
  </section>
</template>
