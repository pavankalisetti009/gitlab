<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import { TYPENAME_AI_CATALOG_ITEM } from '../constants';

export default {
  name: 'AiCatalogFlow',
  components: {
    GlEmptyState,
    GlLoadingIcon,
  },
  data() {
    return {
      aiCatalogFlow: {},
    };
  },
  apollo: {
    aiCatalogFlow: {
      query: aiCatalogFlowQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        createAlert({
          message: error.message,
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlow.loading;
    },
    isFlowNotFound() {
      return this.aiCatalogFlow && Object.keys(this.aiCatalogFlow).length === 0;
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-empty-state
      v-else-if="isFlowNotFound"
      :title="s__('AiCatalog|Flow not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-flow="aiCatalogFlow" />
  </div>
</template>
