<script>
import { GlButton, GlKeysetPagination, GlSprintf } from '@gitlab/ui';
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
    GlButton,
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
    disableConfirmTitle: {
      type: String,
      required: false,
      default: undefined,
    },
    disableConfirmMessage: {
      type: String,
      required: false,
      default: undefined,
    },
    disableFn: {
      type: Function,
      required: false,
      default: undefined,
    },
    search: {
      type: String,
      required: false,
      default: '',
    },
    emptyStateTitle: {
      type: String,
      required: true,
    },
    emptyStateDescription: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateButtonHref: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateButtonText: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['next-page', 'prev-page'],
  data() {
    return {
      itemToDisable: null,
    };
  },
  computed: {
    hasActionItems() {
      return Boolean(this.itemTypeConfig.disableActionItem || this.itemTypeConfig.actionItems);
    },
    disableActionText() {
      return this.itemTypeConfig.disableActionItem?.text || __('Disable');
    },
  },
  methods: {
    async disableItem() {
      await this.disableFn?.(this.itemToDisable);

      this.itemToDisable = null;
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
          @disable="itemToDisable = item"
        />
      </ul>

      <gl-keyset-pagination
        v-bind="pageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />

      <confirm-action-modal
        v-if="itemToDisable"
        modal-id="disable-item-modal"
        variant="danger"
        :title="disableConfirmTitle"
        :action-fn="disableItem"
        :action-text="disableActionText"
        @close="itemToDisable = null"
      >
        <gl-sprintf :message="disableConfirmMessage">
          <template #name>
            <strong class="gl-wrap-anywhere">{{ itemToDisable.name }}</strong>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <template v-else>
      <slot name="empty-state">
        <resource-lists-empty-state
          :title="emptyStateTitle"
          :description="emptyStateDescription"
          :svg-path="$options.EMPTY_SVG_URL"
          :search="search"
        >
          <template v-if="emptyStateButtonHref" #actions>
            <gl-button variant="confirm" :href="emptyStateButtonHref">
              {{ emptyStateButtonText }}
            </gl-button>
          </template>
        </resource-lists-empty-state>
      </slot>
    </template>
  </div>
</template>
