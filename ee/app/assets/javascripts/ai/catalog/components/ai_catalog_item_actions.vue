<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlModalDirective,
  GlSprintf,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import AiCatalogItemConsumerModal from './ai_catalog_item_consumer_modal.vue';

export default {
  name: 'AiCatalogItemActions',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlSprintf,
    ConfirmActionModal,
    AiCatalogItemConsumerModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  inject: {
    isGlobal: {
      default: false,
    },
    projectId: {
      default: null,
    },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    itemRoutes: {
      type: Object,
      required: true,
    },
    isAgentsAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    isFlowsAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    disableFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    deleteFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    deleteConfirmTitle: {
      type: String,
      required: false,
      default: null,
    },
    deleteConfirmMessage: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['add-to-target'],
  data() {
    return {
      showDeleteModal: false,
      showDisableModal: false,
    };
  },
  computed: {
    canAdmin() {
      return Boolean(this.item.userPermissions?.adminAiCatalogItem);
    },
    canUse() {
      return isLoggedIn();
    },
    isEnabled() {
      return this.item.configurationForProject?.enabled;
    },
    showDisable() {
      return this.canAdmin && !this.isGlobal && this.isEnabled;
    },
    showEnable() {
      return this.canAdmin && !this.isGlobal && !this.isEnabled;
    },
    showAddToProject() {
      return this.canUse && this.isGlobal;
    },
    showAddToGroup() {
      return this.canUse && this.isGlobal && (this.isFlowsAvailable || this.isAgentsAvailable);
    },
    duplicateItemProps() {
      return {
        text: s__('AICatalog|Duplicate'),
        to: {
          name: this.itemRoutes.duplicate,
          params: { id: this.$route.params.id },
        },
      };
    },
    disableConfirmMessage() {
      return s__(
        'AICatalog|Are you sure you want to disable agent %{name}? The agent and any associated flows and triggers will no longer work in this project.',
      );
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <gl-button
      v-if="canAdmin"
      :to="{ name: itemRoutes.edit, params: { id: $route.params.id } }"
      category="secondary"
      icon="pencil"
      data-testid="edit-button"
    >
      {{ __('Edit') }}
    </gl-button>
    <gl-button
      v-if="showAddToGroup"
      v-gl-modal="'add-item-consumer-modal'"
      variant="confirm"
      category="primary"
      data-testid="add-to-group-button"
    >
      {{ s__('AICatalog|Enable in group') }}
    </gl-button>
    <gl-button
      v-else-if="showAddToProject"
      v-gl-modal="'add-item-consumer-modal'"
      variant="confirm"
      category="primary"
      data-testid="add-to-project-button"
    >
      {{ s__('AICatalog|Enable in project') }}
    </gl-button>
    <gl-button
      v-else-if="showEnable"
      v-gl-modal="'add-item-consumer-modal'"
      variant="confirm"
      category="primary"
      data-testid="enable-button"
    >
      {{ __('Enable') }}
    </gl-button>
    <gl-disclosure-dropdown
      v-if="canAdmin || canUse"
      :toggle-text="__('More actions')"
      category="tertiary"
      icon="ellipsis_v"
      no-caret
      text-sr-only
      data-testid="more-actions-dropdown"
    >
      <gl-disclosure-dropdown-item
        v-if="canUse"
        :item="duplicateItemProps"
        data-testid="duplicate-button"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="duplicate" variant="current" aria-hidden="true" />
            {{ s__('AICatalog|Duplicate') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item
        v-if="showDisable"
        data-testid="disable-button"
        @action="showDisableModal = true"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="cancel" variant="current" aria-hidden="true" />
            {{ __('Disable') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item
        v-if="canAdmin"
        variant="danger"
        data-testid="delete-button"
        @action="showDeleteModal = true"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="remove" variant="current" aria-hidden="true" />
            {{ __('Delete') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
    </gl-disclosure-dropdown>
    <confirm-action-modal
      v-if="canAdmin && showDeleteModal"
      modal-id="delete-item-modal"
      variant="danger"
      :title="deleteConfirmTitle"
      :action-fn="deleteFn"
      :action-text="__('Delete')"
      @close="showDeleteModal = false"
    >
      <gl-sprintf :message="deleteConfirmMessage">
        <template #name>
          <strong>{{ item.name }}</strong>
        </template>
      </gl-sprintf>
    </confirm-action-modal>
    <confirm-action-modal
      v-if="showDisableModal"
      modal-id="disable-item-modal"
      variant="danger"
      :title="s__('AICatalog|Disable agent')"
      :action-fn="disableFn"
      :action-text="__('Disable')"
      @close="showDisableModal = false"
    >
      <gl-sprintf :message="disableConfirmMessage">
        <template #name>
          <strong>{{ item.name }}</strong>
        </template>
      </gl-sprintf>
    </confirm-action-modal>
    <ai-catalog-item-consumer-modal
      v-if="canUse"
      :item="item"
      :is-project-namespace="showEnable"
      :show-add-to-group="showAddToGroup"
      @submit="$emit('add-to-target', $event)"
    />
  </div>
</template>
