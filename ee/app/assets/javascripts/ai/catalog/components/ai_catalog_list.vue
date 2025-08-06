<script>
import { GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import AiCatalogListItem from './ai_catalog_list_item.vue';

export default {
  name: 'AiCatalogList',
  components: {
    AiCatalogListItem,
    ConfirmActionModal,
    GlSkeletonLoader,
    GlSprintf,
    ResourceListsEmptyState,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    deleteConfirmTitle: {
      type: String,
      required: false,
      default: '',
    },
    deleteConfirmMessage: {
      type: String,
      required: false,
      default: '',
    },
    deleteFn: {
      type: Function,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      itemToDelete: null,
    };
  },
  methods: {
    async deleteItem() {
      await this.deleteFn(this.itemToDelete.id);

      this.itemToDelete = null;
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div data-testid="ai-catalog-list">
    <gl-skeleton-loader v-if="isLoading" :lines="2" />

    <template v-else-if="items.length > 0">
      <ul class="gl-list-none gl-p-0">
        <ai-catalog-list-item
          v-for="item in items"
          :key="item.id"
          :item="item"
          :item-type-config="itemTypeConfig"
          @delete="itemToDelete = item"
        />
      </ul>

      <confirm-action-modal
        v-if="itemToDelete"
        modal-id="delete-item-modal"
        variant="danger"
        :title="deleteConfirmTitle"
        :action-fn="deleteItem"
        :action-text="__('Delete')"
        @close="itemToDelete = null"
      >
        <gl-sprintf :message="deleteConfirmMessage">
          <template #name>
            <strong>{{ itemToDelete.name }}</strong>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <resource-lists-empty-state
      v-else
      :title="s__('AICatalog|Get started with the AI Catalog')"
      :description="
        s__('AICatalog|Build AI agents and flows to automate repetitive tasks and processes.')
      "
      :svg-path="$options.EMPTY_SVG_URL"
    />
  </div>
</template>
