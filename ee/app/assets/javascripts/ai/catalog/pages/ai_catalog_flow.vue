<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';

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
    projectId: {
      default: null,
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
          hasProject: Boolean(this.projectId),
          // projectId is non-nullable in GraphQL query, so we need a fallback value.
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
        };
      },
      update(data) {
        const item = data?.aiCatalogItem || {};
        if (![AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(item.itemType)) {
          return {};
        }
        return item;
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
    isProject() {
      return Boolean(this.projectId);
    },
    isGroup() {
      return !this.isProject && !this.isGlobal;
    },
    hasNoConsumer() {
      return this.isProject && !this.aiCatalogFlow?.configurationForProject;
    },
    shouldShowLatestVersion() {
      return this.isGlobal || this.isGroup || this.hasNoConsumer;
    },
    versionData() {
      return this.shouldShowLatestVersion
        ? this.aiCatalogFlow.latestVersion
        : this.aiCatalogFlow.configurationForProject.pinnedItemVersion;
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

    <router-view v-else :ai-catalog-flow="aiCatalogFlow" :version-data="versionData" />
  </div>
</template>
