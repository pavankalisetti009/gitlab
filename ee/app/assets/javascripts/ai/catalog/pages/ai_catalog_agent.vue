<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';

export default {
  name: 'AiCatalogAgent',
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
      aiCatalogAgent: {},
      errors: [],
    };
  },
  apollo: {
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobal,
          hasProject: Boolean(this.projectId),
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        this.errors = [s__('AICatalog|Agent does not exist')];
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgent.loading;
    },
    isAgentNotFound() {
      return this.aiCatalogAgent && Object.keys(this.aiCatalogAgent).length === 0;
    },
    isProject() {
      return Boolean(this.projectId);
    },
    isGroup() {
      return !this.isProject && !this.isGlobal;
    },
    hasNoConsumer() {
      return this.isProject && !this.aiCatalogAgent?.configurationForProject;
    },
    shouldShowLatestVersion() {
      return this.isGlobal || this.isGroup || this.hasNoConsumer;
    },
    versionData() {
      let version;
      if (this.shouldShowLatestVersion) {
        version = this.aiCatalogAgent.latestVersion;
      } else {
        version = this.aiCatalogAgent.configurationForProject?.pinnedItemVersion;
      }
      return {
        systemPrompt: version.systemPrompt,
        tools: version.tools?.nodes || [],
      };
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
      v-else-if="isAgentNotFound"
      :title="s__('AICatalog|Agent not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-agent="aiCatalogAgent" :version-data="versionData" />
  </div>
</template>
