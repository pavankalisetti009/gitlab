<script>
import { GlButton, GlCollapsibleListbox, GlIcon, GlModal } from '@gitlab/ui';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import { __, s__, sprintf } from '~/locale';

export default {
  cancelRemoveStatus: {
    text: __('Cancel'),
  },
  confirmRemoveStatus: {
    text: s__('WorkItem|Remove status'),
    attributes: {
      variant: 'confirm',
    },
  },
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlModal,
  },
  props: {
    statusCounts: {
      type: Array,
      required: false,
      default: () => [],
    },
    statusToRemove: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    statuses: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      selectedNewStatusId: this.statuses.find((status) => status.id !== this.statusToRemove.id).id,
    };
  },
  computed: {
    bodyText() {
      return sprintf(
        s__(
          `WorkItem|%{count} items currently use the status '%{status}'. Select a new status for these items.`,
        ),
        {
          count: this.count,
          status: this.statusToRemove.name,
        },
      );
    },
    count() {
      return (
        this.statusCounts.find((statusCount) => statusCount.status.id === this.statusToRemove.id)
          ?.count ?? '0'
      );
    },
    items() {
      return this.statuses
        .filter((status) => status.id !== this.statusToRemove.id)
        .map((status) => ({
          ...status,
          text: status.name,
          value: status.id,
        }));
    },
    selectedNewStatus() {
      return this.statuses.find((status) => status.id === this.selectedNewStatusId) ?? {};
    },
  },
  methods: {
    getColorStyle({ color }) {
      return { color: getAdaptiveStatusColor(color) };
    },
  },
};
</script>

<template>
  <gl-modal
    :action-cancel="$options.cancelRemoveStatus"
    :action-primary="$options.confirmRemoveStatus"
    modal-id="remove-status-modal"
    :title="s__('WorkItem|Remove status')"
    visible
    @hidden="$emit('hidden')"
  >
    <p>{{ bodyText }}</p>
    <div class="gl-flex gl-gap-8">
      <div>
        <div class="gl-mb-1 gl-font-bold gl-text-strong">
          {{ s__('WorkItem|Current status') }}
        </div>
        <div data-testid="current-status-value">
          <gl-icon
            class="gl-mr-1"
            :name="statusToRemove.iconName"
            :size="12"
            :style="getColorStyle(statusToRemove)"
          />
          {{ statusToRemove.name }}
        </div>
      </div>
      <div>
        <label class="gl-mb-1 gl-block" for="new-status">
          {{ s__('WorkItem|New status') }}
        </label>
        <gl-collapsible-listbox v-model="selectedNewStatusId" :items="items" toggle-id="new-status">
          <template #toggle>
            <gl-button>
              <gl-icon
                class="!gl-mr-1"
                :name="selectedNewStatus.iconName"
                :size="12"
                :style="getColorStyle(selectedNewStatus)"
              />
              {{ selectedNewStatus.name }}
              <gl-icon name="chevron-down" />
            </gl-button>
          </template>
          <template #list-item="{ item }">
            <gl-icon
              class="gl-mr-1"
              :name="item.iconName"
              :size="12"
              :style="getColorStyle(item)"
            />
            {{ item.name }}
          </template>
        </gl-collapsible-listbox>
      </div>
    </div>
  </gl-modal>
</template>
