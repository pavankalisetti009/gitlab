<script>
import { GlAlert, GlKeysetPagination, GlCard, GlTable, GlBadge, GlProgressBar } from '@gitlab/ui';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getSubscriptionUsersUsageQuery from '../graphql/get_subscription_users_usage.query.graphql';
import { PAGE_SIZE } from '../constants';

export default {
  name: 'UsageByUserTab',
  components: {
    UserAvatarLink,
    GlAlert,
    GlCard,
    GlTable,
    GlBadge,
    GlProgressBar,
    GlKeysetPagination,
  },
  inject: {
    userUsagePath: 'userUsagePath',
    namespacePath: {
      default: null,
    },
  },
  props: {
    hasCommitment: {
      required: true,
      type: Boolean,
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
          // Note: namespacePath will be present on SaaS only, indicating a root group.
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
        this.hasCommitment && {
          key: 'poolUsed',
          label: s__('UsageBilling|Pool used'),
        },
        {
          key: 'totalCreditsUsed',
          label: s__('UsageBilling|Total credits used'),
        },
        {
          key: 'status',
          label: s__('UsageBilling|Status'),
        },
      ].filter(Boolean);
    },
  },
  methods: {
    getStatusVariant(status) {
      switch (status) {
        case 'seat':
          return { variant: 'neutral', label: s__('UsageBilling|Normal usage') };
        case 'pool':
          return { variant: 'info', label: s__('UsageBilling|Using pool') };
        case 'overage':
          return { variant: 'warning', label: s__('UsageBilling|Using overage') };
        case 'blocked':
          return { variant: 'danger', label: s__('UsageBilling|Blocked') };
        default:
          return { variant: 'neutral', label: s__('UsageBilling|Unknown') };
      }
    },
    formatAllocationUsed(allocationUsed, allocationTotal) {
      return `${allocationUsed} / ${allocationTotal}`;
    },
    getUserUsagePath(userId) {
      return this.userUsagePath.replace(':id', userId);
    },
    getProgressBarValue(item) {
      if (item.allocationTotal > 0) {
        return Math.min(100, (item.allocationUsed / item.allocationTotal) * 100);
      }

      return 0;
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
    <dl class="gl-my-3 gl-grid gl-grid-cols-1 gl-gap-5 gl-py-5 @lg/panel:gl-grid-cols-3">
      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">{{ usersUsage.totalUsers }}</dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Total users (active users)') }}</dt>
        </div>
      </gl-card>

      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">
            {{ usersUsage.totalUsersUsingAllocation }}
          </dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Users using allocation') }}</dt>
        </div>
      </gl-card>

      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">
            {{ usersUsage.totalUsersBlocked }}
          </dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Users blocked') }}</dt>
        </div>
      </gl-card>
    </dl>

    <gl-table
      :items="usersUsage.users.nodes"
      :fields="tableFields"
      :busy="false"
      show-empty
      stacked="md"
      class="gl-w-full"
    >
      <template #cell(user)="{ item: user }">
        <div class="gl-display-flex gl-align-items-center">
          <user-avatar-link
            :username="user.name"
            :link-href="getUserUsagePath(user.id)"
            :img-alt="user.name"
            :img-src="user.avatarUrl"
            :img-size="32"
            tooltip-placement="bottom"
            class="gl-items-center gl-gap-3"
          />
        </div>
      </template>

      <template #cell(allocationUsed)="{ item }">
        <div class="gl-display-flex gl-flex-direction-column">
          <span class="gl-font-weight-semibold gl-text-gray-900">
            {{ formatAllocationUsed(item.allocationUsed, item.allocationTotal) }}
          </span>
          <gl-progress-bar :value="getProgressBarValue(item)" class="gl-mt-1" />
        </div>
      </template>

      <template #cell(poolUsed)="{ item }">
        <span class="gl-font-weight-semibold gl-text-gray-900">
          {{ item.poolUsed }}
        </span>
      </template>

      <template #cell(totalCreditsUsed)="{ item }">
        <span class="gl-font-weight-semibold gl-text-gray-900">
          {{ item.totalCreditsUsed }}
        </span>
      </template>

      <template #cell(status)="{ item }">
        <gl-badge :variant="getStatusVariant(item.status).variant" size="sm">
          {{ getStatusVariant(item.status).label }}
        </gl-badge>
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
