<script>
import { GlCard, GlTable, GlBadge, GlProgressBar } from '@gitlab/ui';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { s__, __ } from '~/locale';

export default {
  name: 'UsageByUserTab',
  components: {
    UserAvatarLink,
    GlCard,
    GlTable,
    GlBadge,
    GlProgressBar,
  },
  inject: ['userUsagePath'],
  props: {
    usersData: {
      type: Object,
      required: true,
    },
  },
  computed: {
    tableFields() {
      return [
        {
          key: 'user',
          label: __('User'),
          sortable: true,
        },
        {
          key: 'allocationUsed',
          label: s__('UsageBilling|Allocation used'),
          sortable: true,
        },
        {
          key: 'poolUsed',
          label: s__('UsageBilling|Pool used'),
          sortable: true,
        },
        {
          key: 'totalUnitsUsed',
          label: s__('UsageBilling|Total units used'),
          sortable: true,
        },
        {
          key: 'status',
          label: s__('UsageBilling|Status'),
          sortable: true,
        },
      ];
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
  },
};
</script>

<template>
  <section>
    <dl class="gl-my-3 gl-grid gl-grid-cols-1 gl-gap-5 gl-py-5 lg:gl-grid-cols-3">
      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">{{ usersData.totalUsers }}</dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Total users (active users)') }}</dt>
        </div>
      </gl-card>

      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">
            {{ usersData.totalUsersUsingAllocation }}
          </dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Users using allocation') }}</dt>
        </div>
      </gl-card>

      <gl-card class="gl-bg-transparent gl-p-3">
        <div class="gl-flex gl-flex-col">
          <dd class="gl-font-weight-bold gl-heading-scale-500">
            {{ usersData.totalUsersBlocked }}
          </dd>
          <dt class="gl-font-normal">{{ s__('UsageBilling|Users blocked') }}</dt>
        </div>
      </gl-card>
    </dl>

    <gl-table
      :items="usersData.users"
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
          <gl-progress-bar
            :value="Math.min(100, (item.allocationUsed / item.allocationTotal) * 100)"
            class="gl-mt-1"
          />
        </div>
      </template>

      <template #cell(poolUsed)="{ item }">
        <span class="gl-font-weight-semibold gl-text-gray-900">
          {{ item.poolUsed }}
        </span>
      </template>

      <template #cell(totalUnitsUsed)="{ item }">
        <span class="gl-font-weight-semibold gl-text-gray-900">
          {{ item.totalUnitsUsed }}
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
  </section>
</template>
