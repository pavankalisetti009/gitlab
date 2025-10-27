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
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import AiCatalogItemConsumerModal from './ai_catalog_item_consumer_modal.vue';
import AiCatalogTestRunModal from './ai_catalog_test_run_modal.vue';

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
    AiCatalogTestRunModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  inject: {
    isGlobal: {
      default: false,
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
    };
  },
  computed: {
    canAdmin() {
      return Boolean(this.item.userPermissions?.adminAiCatalogItem);
    },
    canUse() {
      return isLoggedIn();
    },
    showRun() {
      return this.canAdmin && this.item.itemType === AI_CATALOG_TYPE_AGENT;
    },
    showAddToProject() {
      return this.canUse && this.isGlobal;
    },
    showAddToProjectOrGroup() {
      return (
        this.showAddToProject &&
        [AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(this.item.itemType)
      );
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
      v-if="showRun"
      v-gl-modal="'ai-catalog-test-run-modal'"
      category="secondary"
      icon="work-item-test-case"
      data-testid="test-button"
    >
      {{ s__('AICatalog|Test') }}
    </gl-button>
    <gl-button
      v-if="showAddToProjectOrGroup"
      v-gl-modal="'add-item-consumer-modal'"
      variant="confirm"
      category="primary"
      data-testid="add-to-project-or-group-button"
    >
      {{ s__('AICatalog|Enable in project or group') }}
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
          <span>
            <gl-icon name="duplicate" class="gl-mr-2" variant="current" aria-hidden="true" />
            {{ s__('AICatalog|Duplicate') }}
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
          <span>
            <gl-icon name="remove" class="gl-mr-2" variant="current" aria-hidden="true" />
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
    <ai-catalog-test-run-modal v-if="showRun" :item="item" />
    <ai-catalog-item-consumer-modal
      v-if="canUse"
      :item="item"
      :show-add-to-group="showAddToProjectOrGroup"
      @submit="$emit('add-to-target', $event)"
    />
  </div>
</template>
