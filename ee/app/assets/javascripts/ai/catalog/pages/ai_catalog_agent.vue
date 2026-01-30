<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { fetchPolicies } from '~/lib/graphql';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';
import { resolveVersion } from '../utils';

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
    rootGroupId: {
      default: null,
    },
    groupId: {
      default: null,
    },
  },
  data() {
    return {
      aiCatalogAgent: {},
      activeVersionKey: null,
      errors: [],
    };
  },
  apollo: {
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        const hasGroup = Boolean(this.projectId ? this.rootGroupId : this.groupId);
        const groupId = this.projectId ? this.rootGroupId : this.groupId;

        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobal,
          hasProject: Boolean(this.projectId),
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
          hasGroup,
          groupId: convertToGraphQLId(TYPENAME_GROUP, groupId || '0'),
        };
      },
      // fetchPolicy needed to refresh item after updating triggers
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        const item = data?.aiCatalogItem || {};
        if (![AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(item.itemType)) {
          return {};
        }
        return item;
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
    hasParentConsumer() {
      return this.aiCatalogAgent?.configurationForGroup?.enabled;
    },
    isEnabled() {
      return this.groupId
        ? Boolean(this.aiCatalogAgent?.configurationForGroup?.enabled)
        : Boolean(this.aiCatalogAgent?.configurationForProject?.enabled);
    },
    resolvedVersion() {
      return resolveVersion(this.aiCatalogAgent, this.isGlobal);
    },
    isUpdateAvailable() {
      const latestVersion = this.aiCatalogAgent.latestVersion.versionName;
      const pinnedVersion = this.resolvedVersion.versionName;

      // The backend always bumps *up*, so we don't need a complex comparison
      return this.isEnabled && latestVersion !== pinnedVersion;
    },
    version() {
      return {
        isUpdateAvailable: this.isUpdateAvailable,
        activeVersionKey: this.activeVersionKey ?? this.resolvedVersion.key,
        baseVersionKey: this.resolvedVersion.key,
        setActiveVersionKey: (selectedKey) => {
          this.activeVersionKey = selectedKey;
        },
      };
    },
  },
  watch: {
    aiCatalogAgent: {
      handler() {
        if (this.aiCatalogAgent?.name) {
          document.title = `${this.aiCatalogAgent.name} · ${this.baseTitle}`;
        }
      },
      deep: true,
    },
  },
  created() {
    const itemType = s__('AICatalog|Agents');
    this.baseTitle = document.title.includes(itemType)
      ? document.title
      : `${itemType} · ${document.title}`;
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

    <router-view
      v-else
      :ai-catalog-agent="aiCatalogAgent"
      :version="version"
      :has-parent-consumer="hasParentConsumer"
    />
  </div>
</template>
