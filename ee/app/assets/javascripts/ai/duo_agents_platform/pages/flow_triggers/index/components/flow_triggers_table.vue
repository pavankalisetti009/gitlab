<script>
import {
  GlAvatar,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlButtonGroup,
  GlIcon,
  GlLink,
  GlTableLite,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';

const thClass = 'gl-whitespace-nowrap';
const truncateClasses = 'md:gl-truncate md:gl-max-w-0 md:gl-whitespace-nowrap';

export default {
  name: 'FlowTriggersTable',
  components: {
    GlTableLite,
    GlButton,
    GlButtonGroup,
    GlIcon,
    GlBadge,
    GlAvatar,
    GlAvatarLink,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    aiFlowTriggers: {
      type: Array,
      required: true,
    },
  },
  fields: [
    {
      key: 'description',
      label: s__('DuoAgentsPlatform|Description'),
      thClass,
      tdClass: truncateClasses,
      columnClass: 'gl-w-7/20',
    },
    {
      key: 'eventType',
      label: s__('DuoAgentsPlatform|Event Type'),
      thClass,
      columnClass: 'gl-w-3/20',
    },
    {
      key: 'configPath',
      label: s__('DuoAgentsPlatform|Config Path'),
      thClass,
      tdClass: truncateClasses,
      columnClass: 'gl-w-6/20',
    },
    {
      key: 'user',
      label: s__('DuoAgentsPlatform|Owner'),
      thClass,
      columnClass: 'gl-w-2/20',
    },
    {
      key: 'actions',
      label: s__('DuoAgentsPlatform|Actions'),
      thClass: [thClass, 'gl-text-right'],
      columnClass: 'gl-w-3/20',
    },
  ],
  eventTypes: {
    0: s__('DuoAgentsPlatform|Mention'),
    1: s__('DuoAgentsPlatform|Assign'),
  },
};
</script>

<template>
  <gl-table-lite :fields="$options.fields" :items="aiFlowTriggers" stacked="md">
    <template #table-colgroup="{ fields }">
      <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
    </template>

    <template #cell(description)="{ item }">
      <span class="gl-flex">
        <span class="gl-min-w-0 gl-truncate">
          {{ item.description }}
        </span>
      </span>
    </template>

    <template #cell(eventType)="{ item }">
      <div class="gl-flex gl-flex-wrap gl-gap-2" data-testid="flow-trigger-badges">
        <gl-badge v-for="eventType in item.eventTypes" :key="eventType" variant="info">
          {{ $options.eventTypes[eventType] }}
        </gl-badge>
      </div>
    </template>

    <template #cell(configPath)="{ item }">
      <gl-link
        v-if="item.configPath"
        data-testid="flow-trigger-config-path"
        :href="item.configUrl"
        class="gl-flex gl-gap-2"
      >
        <gl-icon name="doc-text" class="gl-shrink-0 gl-text-subtle" />
        <span class="gl-truncate">
          {{ item.configPath }}
        </span>
      </gl-link>
      <span v-else data-testid="flow-trigger-config-path-fallback" class="gl-text-subtle">
        {{ s__('DuoAgentsPlatform|Default') }}
      </span>
    </template>

    <template #cell(user)="{ item }">
      <gl-avatar-link
        v-if="item.user"
        v-gl-tooltip
        :href="item.user.webPath"
        :title="item.user.username"
      >
        <gl-avatar :size="32" :src="item.user.avatarUrl" :alt="item.user.username" />
      </gl-avatar-link>
      <span v-else class="gl-text-subtle">
        {{ s__('DuoAgentsPlatform|Unknown') }}
      </span>
    </template>

    <template #cell(actions)="{ item }">
      <div class="gl-flex gl-justify-end">
        <gl-button-group>
          <gl-button
            v-gl-tooltip
            :title="s__('DuoAgentsPlatform|Edit trigger')"
            :aria-label="s__('DuoAgentsPlatform|Edit trigger')"
            :href="item.editPath"
            icon="pencil"
          />
          <gl-button
            v-gl-tooltip
            :title="s__('DuoAgentsPlatform|Delete trigger')"
            :aria-label="s__('DuoAgentsPlatform|Delete trigger')"
            data-testid="flow-trigger-delete-action"
            icon="remove"
            variant="danger"
            @click="$emit('delete-trigger', item.id)"
          />
        </gl-button-group>
      </div>
    </template>
  </gl-table-lite>
</template>
