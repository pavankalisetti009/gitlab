<script>
import {
  GlBadge,
  GlTableLite,
  GlToggle,
  GlSkeletonLoader,
  GlLink,
  GlAlert,
  GlKeysetPagination,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

import AvailabilityPopover from '../components/availability_popover.vue';
import GetOrganizationWorkspacesClusterAgentsQuery from '../components/get_organization_workspaces_cluster_agents_query.vue';

import { AVAILABILITY_TEXT } from '../constants';

export default {
  name: 'WorkspacesAgentAvailabilityApp',
  components: {
    SettingsBlock,
    GetOrganizationWorkspacesClusterAgentsQuery,
    AvailabilityPopover,
    GlTableLite,
    GlBadge,
    GlToggle,
    GlSkeletonLoader,
    GlLink,
    GlAlert,
    GlKeysetPagination,
  },
  inject: {
    organizationId: {
      type: String,
      default: '',
    },
    defaultExpanded: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    getAvailabilityText(availability) {
      return AVAILABILITY_TEXT[availability] ?? null;
    },
    getStatusBadgeMetadata(item) {
      const { isConnected } = item;
      return {
        text: isConnected ? s__('Workspaces|Connected') : s__('Workspaces|Not connected'),
        variant: isConnected ? 'success' : 'neutral',
      };
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('Workspaces|Name'),
    },
    {
      key: 'group',
      label: s__('Workspaces|Group'),
    },
    {
      key: 'project',
      label: s__('Workspaces|Project'),
    },
    {
      key: 'status',
      label: s__('Workspaces|Status'),
    },
    {
      key: 'availability',
      label: s__('Workspaces|Availability'),
    },
  ],
};
</script>
<template>
  <settings-block
    :title="s__('Workspaces|Workspaces Agent Availability')"
    :default-expanded="defaultExpanded"
  >
    <template #description>
      {{
        s__(
          'Workspaces|Configure which Kubernetes agents are available for new workspaces. These settings do not affect existing workspaces.',
        )
      }}
    </template>
    <template #default>
      <get-organization-workspaces-cluster-agents-query :organization-id="organizationId">
        <template #default="{ loading, pagination, agents, error }">
          <div>
            <gl-alert v-if="error" variant="danger" :dismissible="false"
              >{{ s__('Workspaces|Could not load agents. Refresh the page to try again.') }}
            </gl-alert>
            <gl-skeleton-loader v-else-if="loading" :lines="5" :width="600" />
            <div
              v-else-if="!loading && !agents.length"
              data-testid="agent-availability-empty-state"
            >
              {{ s__('Workspaces|No agents available') }}
            </div>
            <div v-else class="gl-flex gl-flex-col gl-items-center gl-gap-3">
              <gl-table-lite
                responsive
                :items="agents"
                :fields="$options.fields"
                :aria-busy="loading"
              >
                <template #head(availability)="{ label }">
                  <div class="gl-flex gl-items-center gl-gap-3">
                    <span>{{ label }}</span>
                    <availability-popover />
                  </div>
                </template>
                <template #cell(name)="{ item }">
                  <gl-link class="gl-font-bold" :href="item.url" target="_blank">{{
                    item.name
                  }}</gl-link>
                </template>
                <template #cell(status)="{ item }">
                  <gl-badge :variant="getStatusBadgeMetadata(item).variant">{{
                    getStatusBadgeMetadata(item).text
                  }}</gl-badge>
                </template>
                <template #cell(availability)="{ item }">
                  <div class="gl-flex gl-items-center gl-gap-3">
                    <gl-toggle
                      :value="item.availability === 'available'"
                      :label="getAvailabilityText(item.availability)"
                      label-position="hidden"
                      class="flex-row"
                    />
                    <p class="gl-mb-0">{{ getAvailabilityText(item.availability) }}</p>
                  </div>
                </template>
              </gl-table-lite>
              <gl-keyset-pagination
                v-if="!loading && pagination.show"
                :has-next-page="pagination.hasNextPage"
                :has-previous-page="pagination.hasPreviousPage"
                @prev="pagination.prevPage"
                @next="pagination.nextPage"
              />
            </div>
          </div>
        </template>
      </get-organization-workspaces-cluster-agents-query>
    </template>
  </settings-block>
</template>
