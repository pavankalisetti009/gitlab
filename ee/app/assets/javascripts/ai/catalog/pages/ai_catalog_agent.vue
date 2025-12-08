<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { AI_CATALOG_TYPE_AGENT, VERSION_PINNED, VERSION_LATEST } from '../constants';
import { getByVersionKey } from '../utils';

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
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobal,
          hasProject: Boolean(this.projectId),
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
          hasGroup: Boolean(this.rootGroupId),
          groupId: convertToGraphQLId(TYPENAME_GROUP, this.rootGroupId || '0'),
        };
      },
      update(data) {
        const item = data?.aiCatalogItem || {};
        if (item.itemType !== AI_CATALOG_TYPE_AGENT) {
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
    isProject() {
      return Boolean(this.projectId);
    },
    isGroup() {
      return !this.isProject && !this.isGlobal;
    },
    hasNoConsumer() {
      return !this.aiCatalogAgent.configurationForProject;
    },
    hasParentConsumer() {
      return this.aiCatalogAgent?.configurationForGroup?.enabled;
    },
    shouldShowLatestVersion() {
      // Always show latest version in Explore/Group namespaces. Project namespace should show pinned version,
      // but when navigation to an Item from the Managed tab, we aren't able to flag to the show page (this component)
      // that it needs to show the latest version once we cross the router boundary.
      // This is known: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/214607#note_2923544884
      return this.isGlobal || this.isGroup;
    },
    isUpdateAvailable() {
      if (this.shouldShowLatestVersion || this.hasNoConsumer) {
        return false;
      }

      const agent = this.aiCatalogAgent;
      const hasPermissions = Boolean(
        agent.configurationForProject.userPermissions?.adminAiCatalogItemConsumer,
      );
      const latestVersion = getByVersionKey(agent, VERSION_LATEST).humanVersionName;
      const pinnedVersion = getByVersionKey(agent, VERSION_PINNED).humanVersionName;

      // The backend always bumps *up*, so we don't need a complex comparison
      return hasPermissions && latestVersion !== pinnedVersion;
    },
    baseVersionKey() {
      return this.shouldShowLatestVersion || this.hasNoConsumer ? VERSION_LATEST : VERSION_PINNED;
    },
    version() {
      return {
        isUpdateAvailable: this.isUpdateAvailable,
        activeVersionKey: this.activeVersionKey ?? this.baseVersionKey,
        setActiveVersionKey: (selectedKey) => {
          this.activeVersionKey = selectedKey;
        },
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

    <router-view
      v-else
      :ai-catalog-agent="aiCatalogAgent"
      :version="version"
      :has-parent-consumer="hasParentConsumer"
    />
  </div>
</template>
