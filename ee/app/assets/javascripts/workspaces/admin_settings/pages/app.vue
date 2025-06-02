<script>
import { GlBadge, GlTableLite, GlToggle, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

import { AVAILABILITY_TEXT, CONNECTION_STATUS_TEXT, CONNECTION_STATUS } from '../constants';
import AvailabilityPopover from '../components/availability_popover.vue';

export default {
  name: 'WorkspacesAgentAvailabilityApp',
  components: {
    SettingsBlock,
    AvailabilityPopover,
    GlTableLite,
    GlBadge,
    GlToggle,
    GlLink,
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
      availability: 'available',
      status: 'connected',
      url: '',
    },
    {
      name: 'ws-agent',
      group: 'GitLab.com',
      project: 'GitLab Shell',
      status: 'not_connected',
      availability: 'blocked',
      url: '',
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
  SETTINGS_TITLE: s__('Workspaces|Workspaces Agent Availability'),
  SETTINGS_DESCRIPTION: s__(
    'Workspaces|Configure which Kubernetes agents are available for new workspaces. These settings do not affect existing workspaces.',
  ),
};
</script>
<template>
  <settings-block :title="$options.SETTINGS_TITLE" :default-expanded="defaultExpanded">
    <template #description>
      {{ $options.SETTINGS_DESCRIPTION }}
    </template>
    <template #default>
      <div>
        <gl-table-lite
          v-if="$options.mockData.length"
          responsive
          :items="$options.mockData"
          :fields="$options.fields"
        >
          <template #head(availability)="{ label }">
            <div class="gl-flex gl-items-center gl-gap-3">
              <span>{{ label }}</span>
              <availability-popover />
            </div>
          </template>
          <template #cell(name)="{ item }">
            <gl-link
              class="gl-font-bold"
              data-test-id="agent-name"
              :href="item.url"
              target="_blank"
              >{{ item.name }}</gl-link
            >
          </template>
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
  </settings-block>
</template>
