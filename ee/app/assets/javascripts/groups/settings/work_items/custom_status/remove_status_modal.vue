<script>
import { GlAlert, GlIcon, GlModal } from '@gitlab/ui';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import { __, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  DEFAULT_STATE_CLOSED,
  DEFAULT_STATE_DUPLICATE,
  DEFAULT_STATE_OPEN,
  DEFAULT_STATE_TO_TEXT_MAP,
  STATUS_CATEGORIES_MAP,
} from 'ee/work_items/constants';
import { getDefaultStateType } from 'ee/work_items/utils';
import lifecycleUpdateMutation from './graphql/lifecycle_update.mutation.graphql';
import RemoveStatusModalListbox from './remove_status_modal_listbox.vue';

export default {
  actionCancel: {
    text: __('Cancel'),
  },
  components: {
    GlAlert,
    GlIcon,
    GlModal,
    RemoveStatusModalListbox,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    lifecycle: {
      type: Object,
      required: true,
    },
    statusToRemove: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      error: '',
      isUpdating: false,
      selectedNewDefaultId: undefined,
      selectedNewStatusId: undefined,
    };
  },
  computed: {
    actionPrimary() {
      return {
        text: s__('WorkItem|Remove status'),
        attributes: {
          loading: this.isUpdating,
          variant: 'confirm',
        },
      };
    },
    newDefaultBodyText() {
      return sprintf(
        s__(
          'WorkItem|This status is set as the %{state} default. Select a new %{state} default to remove this status.',
        ),
        { state: DEFAULT_STATE_TO_TEXT_MAP[this.defaultStatusType] },
      );
    },
    newDefaultLabel() {
      return sprintf(s__('WorkItem|%{state} default'), {
        state: DEFAULT_STATE_TO_TEXT_MAP[this.defaultStatusType],
      });
    },
    newStatusBodyText() {
      return sprintf(
        s__(
          `WorkItem|%{count} items currently use the status '%{status}'. Select a new status for these items.`,
        ),
        {
          count: this.count,
          status: this.statusToRemove.name,
        },
        false, // Don't escape apostrophe in "Won't do"
      );
    },
    count() {
      return (
        this.lifecycle.statusCounts.find(
          (statusCount) => statusCount.status.id === this.statusToRemove.id,
        )?.count ?? '0'
      );
    },
    filteredStatuses() {
      // Only show statuses in the same open or closed state
      const state = STATUS_CATEGORIES_MAP[this.statusToRemove.category.toUpperCase()].workItemState;
      return this.lifecycle.statuses.filter((status) => {
        return (
          state === STATUS_CATEGORIES_MAP[status.category.toUpperCase()].workItemState &&
          status.id !== this.statusToRemove.id
        );
      });
    },
    defaultStatusType() {
      return getDefaultStateType(this.lifecycle, this.statusToRemove);
    },
    items() {
      return this.filteredStatuses.map((status) => ({
        ...status,
        text: status.name,
        value: status.id,
      }));
    },
    selectedNewDefault() {
      return (
        this.lifecycle.statuses.find((status) => status.id === this.selectedNewDefaultId) ?? {}
      );
    },
    selectedNewStatus() {
      return this.lifecycle.statuses.find((status) => status.id === this.selectedNewStatusId) ?? {};
    },
  },
  beforeMount() {
    const initialSelectedStatusId = this.filteredStatuses.find(
      (status) => status.id !== this.statusToRemove.id,
    )?.id;
    this.selectedNewDefaultId = initialSelectedStatusId;
    this.selectedNewStatusId = initialSelectedStatusId;
  },
  methods: {
    getColorStyle({ color }) {
      return { color: getAdaptiveStatusColor(color) };
    },
    updateStatus(event) {
      event.preventDefault(); // Don't hide the modal yet in case there are errors to show

      this.error = '';
      this.isUpdating = true;

      const input = {
        id: this.lifecycle.id,
        namespacePath: this.fullPath,
      };

      if (this.selectedNewStatusId) {
        input.statusMappings = [
          {
            oldStatusId: this.statusToRemove.id,
            newStatusId: this.selectedNewStatusId,
          },
        ];
      }

      if (this.defaultStatusType && this.selectedNewDefaultId) {
        const statusesIndex = this.lifecycle.statuses.findIndex(
          (status) => status.id === this.selectedNewDefaultId,
        );
        if (this.defaultStatusType === DEFAULT_STATE_CLOSED) {
          input.defaultClosedStatusIndex = statusesIndex;
        }
        if (this.defaultStatusType === DEFAULT_STATE_DUPLICATE) {
          input.defaultDuplicateStatusIndex = statusesIndex;
        }
        if (this.defaultStatusType === DEFAULT_STATE_OPEN) {
          input.defaultOpenStatusIndex = statusesIndex;
        }
      }

      this.$apollo
        .mutate({
          mutation: lifecycleUpdateMutation,
          variables: { input },
        })
        .then(({ data }) => {
          if (data.lifecycleUpdate.errors.length) {
            throw new Error(data.lifecycleUpdate.errors);
          }
          this.$refs.modal.hide();
        })
        .catch((error) => {
          this.error =
            error.message || s__('WorkItem|Something went wrong while updating mappings.');
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.actionCancel"
    :action-primary="actionPrimary"
    modal-id="remove-status-modal"
    :title="s__('WorkItem|Remove status')"
    visible
    @hidden="$emit('hidden')"
    @primary="updateStatus"
  >
    <gl-alert v-if="error" class="gl-mb-3" variant="danger" @dismiss="error = ''">
      {{ error }}
    </gl-alert>
    <p class="gl-mb-4">{{ newStatusBodyText }}</p>
    <div class="gl-mb-6 gl-flex gl-gap-8">
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
        <remove-status-modal-listbox
          v-model="selectedNewStatusId"
          :items="items"
          :selected="selectedNewStatus"
          toggle-id="new-status"
        />
      </div>
    </div>

    <template v-if="Boolean(defaultStatusType)">
      <p class="gl-mb-4">{{ newDefaultBodyText }}</p>
      <div>
        <label class="gl-mb-1 gl-block" for="new-default" data-testid="new-default-label">
          {{ newDefaultLabel }}
        </label>
        <remove-status-modal-listbox
          v-model="selectedNewDefaultId"
          :items="items"
          :selected="selectedNewDefault"
          toggle-id="new-default"
          data-testid="new-default-listbox"
        />
      </div>
    </template>
  </gl-modal>
</template>
