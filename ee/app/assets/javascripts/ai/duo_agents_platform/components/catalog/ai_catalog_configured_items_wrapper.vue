<script>
import { GlButton } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import { sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  AI_CATALOG_CONSUMER_LABELS,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  PAGE_SIZE,
} from 'ee/ai/catalog/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import { DISABLE_SUCCESS, DISABLE_ERROR } from 'ee/ai/catalog/messages';

export default {
  name: 'AiCatalogConfiguredItemsWrapper',
  components: {
    GlButton,
    ResourceListsEmptyState,
    AiCatalogList,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    groupId: {
      default: null,
    },
    projectId: {
      default: null,
    },
  },
  props: {
    disableConfirmTitle: {
      type: String,
      required: false,
      default: null,
    },
    disableConfirmMessage: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateTitle: {
      type: String,
      required: false,
      default: null,
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
    itemTypes: {
      type: Array,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
      validator(item) {
        return item.showRoute && item.visibilityTooltip;
      },
    },
  },
  data() {
    return {
      configuredItems: [],
      pageInfo: {},
      paginationVariables: {
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      },
    };
  },
  apollo: {
    configuredItems: {
      query: aiCatalogConfiguredItemsQuery,
      variables() {
        return {
          itemTypes: this.itemTypes,
          ...this.namespaceVariables,
          ...this.paginationVariables,
        };
      },
      update: (data) => data.aiCatalogConfiguredItems.nodes,
      result({ data }) {
        this.pageInfo = data.aiCatalogConfiguredItems.pageInfo;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.configuredItems.loading;
    },
    isProjectNamespace() {
      return Boolean(this.projectId);
    },
    namespaceVariables() {
      if (this.isProjectNamespace) {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          includeInherited: false,
        };
      }
      return {
        groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
      };
    },
    namespaceTypeLabel() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_PROJECT]
        : AI_CATALOG_CONSUMER_LABELS[AI_CATALOG_CONSUMER_TYPE_GROUP];
    },
    items() {
      return this.configuredItems.map((configuredItem) => {
        const { item, ...itemConsumerData } = configuredItem;
        return {
          ...item,
          itemConsumer: itemConsumerData,
        };
      });
    },
  },
  methods: {
    async disableItem(item) {
      const { id } = item.itemConsumer;
      const { itemType } = item;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogItemConsumer,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogConfiguredItemsQuery],
        });

        if (!data.aiCatalogItemConsumerDelete.success) {
          this.$emit('error', {
            title: DISABLE_ERROR[itemType],
            errors: data.aiCatalogItemConsumerDelete.errors,
          });
          return;
        }

        this.$toast.show(
          sprintf(DISABLE_SUCCESS[itemType], {
            namespaceType: this.namespaceTypeLabel,
          }),
        );
      } catch (error) {
        this.$emit('error', {
          title: DISABLE_ERROR[itemType],
          errors: [error.message],
        });
        Sentry.captureException(error);
      }
    },
    handleNextPage() {
      this.paginationVariables = {
        before: null,
        after: this.pageInfo.endCursor,
        first: PAGE_SIZE,
        last: null,
      };
    },
    handlePrevPage() {
      this.paginationVariables = {
        after: null,
        before: this.pageInfo.startCursor,
        first: null,
        last: PAGE_SIZE,
      };
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <ai-catalog-list
    :is-loading="isLoading"
    :items="items"
    :item-type-config="itemTypeConfig"
    :disable-confirm-title="disableConfirmTitle"
    :disable-confirm-message="disableConfirmMessage"
    :disable-fn="disableItem"
    :page-info="pageInfo"
    @next-page="handleNextPage"
    @prev-page="handlePrevPage"
  >
    <template #empty-state>
      <resource-lists-empty-state
        :title="emptyStateTitle"
        :description="emptyStateDescription"
        :svg-path="$options.EMPTY_SVG_URL"
      >
        <template #actions>
          <gl-button variant="confirm" :href="emptyStateButtonHref">
            {{ emptyStateButtonText }}
          </gl-button>
        </template>
      </resource-lists-empty-state>
    </template>
  </ai-catalog-list>
</template>
