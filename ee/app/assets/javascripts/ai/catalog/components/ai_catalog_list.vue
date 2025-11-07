<script>
import { GlKeysetPagination, GlSprintf } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { __ } from '~/locale';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogListItem from './ai_catalog_list_item.vue';
import AiCatalogListSkeleton from './ai_catalog_list_skeleton.vue';

export default {
  name: 'AiCatalogList',
  components: {
    AiCatalogListItem,
    AiCatalogListSkeleton,
    ConfirmActionModal,
    GlKeysetPagination,
    GlSprintf,
    ResourceListsEmptyState,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
      validator(item) {
        return item.showRoute && item.visibilityTooltip;
      },
    },
    deleteConfirmTitle: {
      type: String,
      required: false,
      default: undefined,
    },
    deleteConfirmMessage: {
      type: String,
      required: false,
      default: undefined,
    },
    deleteFn: {
      type: Function,
      required: false,
      default: undefined,
    },
    search: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      itemToDelete: null,
    };
  },
  computed: {
    hasActionItems() {
      return Boolean(this.itemTypeConfig.deleteActionItem || this.itemTypeConfig.actionItems);
    },
    deleteActionText() {
      return this.itemTypeConfig.deleteActionItem?.text || __('Delete');
    },
  },
  methods: {
    async deleteItem() {
      await this.deleteFn?.(this.itemToDelete);

      this.itemToDelete = null;
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div>
    <ai-catalog-list-skeleton v-if="isLoading" :show-right-element="hasActionItems" />

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

      <gl-keyset-pagination
        v-bind="pageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />

      <confirm-action-modal
        v-if="itemToDelete"
        modal-id="delete-item-modal"
        variant="danger"
        :title="deleteConfirmTitle"
        :action-fn="deleteItem"
        :action-text="deleteActionText"
        @close="itemToDelete = null"
      >
        <gl-sprintf :message="deleteConfirmMessage">
          <template #name>
            <strong>{{ itemToDelete.name }}</strong>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <template v-else>
      <slot name="empty-state">
        <resource-lists-empty-state
          :title="s__('AICatalog|Get started with the AI Catalog')"
          :description="
            s__('AICatalog|Build agents and flows to automate tasks and solve complex problems.')
          "
          :svg-path="$options.EMPTY_SVG_URL"
          :search="search"
        />
      </slot>
    </template>
  </div>
</template>
