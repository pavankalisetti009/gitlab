<script>
import { GlAlert, GlKeysetPagination, GlTable, GlProgressBar } from '@gitlab/ui';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getSubscriptionUsersUsageQuery from '../graphql/get_subscription_users_usage.query.graphql';
import { PAGE_SIZE } from '../constants';

/**
 * @typedef {object} Usage
 * @property { number } totalCredits
 * @property { number } creditsUsed
 * @property { number } poolCreditsUsed
 * @property { number } overageCreditsUsed
 */

export default {
  name: 'UsageByUserTab',
  components: {
    UserAvatarLink,
    GlAlert,
    GlTable,
    GlProgressBar,
    GlKeysetPagination,
  },
  inject: {
    userUsagePath: 'userUsagePath',
    namespacePath: {
      default: null,
    },
  },
  data() {
    return {
      isError: false,
      usersUsage: null,
      pageInfo: {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      },
    };
  },
  apollo: {
    usersUsage: {
      query: getSubscriptionUsersUsageQuery,
      variables() {
        return {
          // NOTE: namespacePath will be present on SaaS only, indicating a root group.
          // SM would pass null in this variable, requesting instance-level data.
          namespacePath: this.namespacePath,
          first: this.pageInfo.first,
          last: this.pageInfo.last,
          after: this.pageInfo.after,
          before: this.pageInfo.before,
        };
      },
      error(error) {
        this.isError = true;
        logError(error);
        captureException(error);
      },
      update(data) {
        return data.subscriptionUsage.usersUsage;
      },
    },
  },
  computed: {
    tableFields() {
      return [
        {
          key: 'user',
          label: __('User'),
        },
        {
          key: 'allocationUsed',
          label: s__('UsageBilling|Allocation used'),
        },
        {
          key: 'totalCreditsUsed',
          label: s__('UsageBilling|Total credits used'),
        },
      ].filter(Boolean);
    },
    usersList() {
      return this.usersUsage.users.nodes.map((user) => ({
        ...user,
        usage: {
          totalCredits: 0,
          creditsUsed: 0,
          poolCreditsUsed: 0,
          overageCreditsUsed: 0,
          ...user.usage,
        },
      }));
    },
  },
  methods: {
    /** @param { Usage } usage */
    getTotalUsage(usage) {
      return usage.creditsUsed + usage.poolCreditsUsed + usage.overageCreditsUsed;
    },
    formatAllocationUsed(allocationUsed, allocationTotal) {
      return `${allocationUsed} / ${allocationTotal}`;
    },
    getUserUsagePath(username) {
      return this.userUsagePath.replace(':username', username);
    },
    /** @param { Usage } usage */
    getProgressBarValue(usage) {
      if (usage.totalCredits === 0) {
        return 0;
      }

      return (usage.creditsUsed / usage.totalCredits) * 100;
    },
    onNextPage(item) {
      this.pageInfo = {
        first: PAGE_SIZE,
        after: item,
        last: null,
        before: null,
      };
    },
    onPrevPage(item) {
      this.pageInfo = {
        first: null,
        after: null,
        last: PAGE_SIZE,
        before: item,
      };
    },
  },
};
</script>

<template>
  <section v-if="$apollo.queries.usersUsage.loading">
    <div class="gl-my-3 gl-grid gl-grid-cols-1 gl-gap-5 gl-py-5 @lg/panel:gl-grid-cols-3">
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
    </div>

    <div class="gl-flex gl-flex-col gl-gap-3">
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
  </section>

  <gl-alert v-else-if="isError" variant="danger" class="gl-my-3">
    {{ s__('UsageBilling|An error occurred while fetching data') }}
  </gl-alert>

  <section v-else>
    <gl-table
      :items="usersList"
      :fields="tableFields"
      :busy="false"
      show-empty
      stacked="md"
      class="gl-mt-5 gl-w-full"
    >
      <template #cell(user)="{ item: user }">
        <div class="gl-flex gl-items-center">
          <user-avatar-link
            :username="user.name"
            :link-href="getUserUsagePath(user.username)"
            :img-alt="user.name"
            :img-src="user.avatarUrl"
            :img-size="32"
            tooltip-placement="bottom"
            class="gl-items-center gl-gap-3"
          />
        </div>
      </template>

      <template #cell(allocationUsed)="{ item }">
        <div class="gl-flex gl-min-h-7 gl-items-center gl-justify-between gl-gap-3">
          <span class="gl-font-weight-semibold gl-text-gray-900">
            {{ formatAllocationUsed(item.usage.creditsUsed, item.usage.totalCredits) }}
          </span>
          <gl-progress-bar
            :value="getProgressBarValue(item.usage)"
            class="gl-h-3 gl-max-w-[160px] gl-flex-1"
          />
        </div>
      </template>

      <template #cell(totalCreditsUsed)="{ item }">
        <div class="gl-font-weight-semibold gl-flex gl-min-h-7 gl-items-center gl-text-gray-900">
          {{ getTotalUsage(item.usage) }}
        </div>
      </template>

      <template #empty>
        <div class="gl-py-6 gl-text-center">
          <p class="gl-mb-0 gl-text-secondary">{{ s__('UsageBilling|No user data available') }}</p>
        </div>
      </template>
    </gl-table>

    <div class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-bind="usersUsage.users.pageInfo"
        @prev="onPrevPage"
        @next="onNextPage"
      />
    </div>
  </section>
</template>
