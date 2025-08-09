<script>
import { GlKeysetPagination, GlSprintf } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogListItem from './ai_catalog_list_item.vue';

export default {
  name: 'AiCatalogList',
  components: {
    AiCatalogListItem,
    ConfirmActionModal,
    GlKeysetPagination,
    GlSprintf,
    ResourceListsLoadingStateList,
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
    pageInfo: {
      type: Object,
      required: true,
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
  <div>
    <resource-lists-loading-state-list v-if="isLoading" />

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
