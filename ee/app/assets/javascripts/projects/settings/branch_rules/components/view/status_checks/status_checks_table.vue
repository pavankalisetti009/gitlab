<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'StatusChecksTable',
  i18n: {
    addStatusCheck: s__('BranchRules|Add status check'),
    statusChecksTitle: s__('BranchRules|Status checks'),
    statusChecksEmptyState: s__('BranchRules|No status checks have been added.'),
    editButton: __('Edit'),
    deleteButton: __('Delete'),
  },
  components: {
    CrudComponent,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <crud-component
    :title="$options.i18n.statusChecksTitle"
    icon="check-circle"
    :count="statusChecks.length"
  >
    <template #actions>
      <gl-button size="small" data-testid="add-btn" @click="$emit('add')">
        {{ $options.i18n.addStatusCheck }}
      </gl-button>
    </template>
    <p v-if="!statusChecks.length" class="gl-text-secondary gl-break-words">
      {{ $options.i18n.statusChecksEmptyState }}
    </p>

    <div
      v-for="statusCheck in statusChecks"
      :key="statusCheck.id"
      class="gl-mb-4 gl-flex gl-items-center gl-gap-5 gl-border-t-1 gl-border-gray-100"
    >
      <div class="gl-flex-1">
        <p class="gl-my-0">{{ statusCheck.name }}</p>
        <p class="gl-my-0 gl-text-secondary">{{ statusCheck.externalUrl }}</p>
      </div>
      <div class="gl-flex gl-gap-2">
        <gl-button
          v-gl-tooltip
          category="tertiary"
          icon="pencil"
          data-testid="edit-btn"
          :title="`${$options.i18n.editButton} ${statusCheck.name}`"
          :aria-label="`${$options.i18n.editButton} ${statusCheck.name}`"
          @click="$emit('edit')"
        />
        <gl-button
          v-gl-tooltip
          category="tertiary"
          icon="remove"
          data-testid="delete-btn"
          :title="`${$options.i18n.deleteButton} ${statusCheck.name}`"
          :aria-label="`${$options.i18n.deleteButton} ${statusCheck.name}`"
          @click="$emit('delete')"
        />
      </div>
    </div>
  </crud-component>
</template>
