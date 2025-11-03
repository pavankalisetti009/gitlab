<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';

export default {
  name: 'AiCatalogFlow',
  components: {
    ErrorsAlert,
    GlEmptyState,
    GlLoadingIcon,
  },
  inject: {
    isGlobal: {
      default: false,
    },
  },
  data() {
    return {
      aiCatalogFlow: {},
      errors: [],
    };
  },
  apollo: {
    aiCatalogFlow: {
      query: aiCatalogFlowQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobal,
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        this.errors = [s__('AICatalog|Flow does not exist')];
        Sentry.captureException(error);
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
    <errors-alert :errors="errors" @dismiss="errors = []" />

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-empty-state
      v-else-if="isFlowNotFound"
      :title="s__('AICatalog|Flow not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-flow="aiCatalogFlow" />
  </div>
</template>
