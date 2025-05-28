<script>
import { GlBadge, GlTableLite, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';

import { AVAILABILITY_TEXT, CONNECTION_STATUS_TEXT, CONNECTION_STATUS } from '../constants';

export default {
  name: 'WorkspacesAgentAvailabilityApp',
  components: {
    GlTableLite,
    GlBadge,
    GlToggle,
  },
  methods: {
    getBadgeVariant(status) {
      switch (status) {
        case CONNECTION_STATUS.CONNECTED:
          return 'success';
        default:
          return 'neutral';
      }
    },
    getStatusText(status) {
      return CONNECTION_STATUS_TEXT[status] ?? null;
    },
    getAvailabilityText(availability) {
      return AVAILABILITY_TEXT[availability] ?? null;
    },
  },
  // TODO: replace with GQL query - https://gitlab.com/gitlab-org/gitlab/-/issues/513370
  mockData: [
    {
      name: 'remotedev',
      group: 'GitLab.com',
      project: 'GitLab Shell',
      status: 'connected',
      availability: 'available',
    },
    {
      name: 'ws-agent',
      group: 'GitLab.com',
      project: 'GitLab Shell',
      status: 'not_connected',
      availability: 'blocked',
    },
  ],
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
  <div>
    <gl-table-lite
      v-if="$options.mockData.length"
      responsive
      :items="$options.mockData"
      :fields="$options.fields"
    >
      <template #cell(status)="{ item }">
        <gl-badge v-if="item.status" :variant="getBadgeVariant(item.status)">{{
          getStatusText(item.status)
        }}</gl-badge>
      </template>
      <template #cell(availability)="{ item }">
        <div class="gl-flex gl-flex-row gl-items-center gl-gap-3">
          <gl-toggle
            :value="item.availability === 'available'"
            :label="getAvailabilityText(item.availability)"
            label-position="hidden"
          />
          <p class="gl-mb-0">{{ getAvailabilityText(item.availability) }}</p>
        </div>
      </template>
    </gl-table-lite>
    <div v-else data-testid="workspaces-agent-availability-empty-state">
      {{ s__('Workspaces|No agents available') }}
    </div>
  </div>
</template>
