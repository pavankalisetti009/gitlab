<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import { getByVersionKey } from '../utils';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  VERSION_PINNED,
  VERSION_LATEST,
} from '../constants';

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
    rootGroupId: {
      default: null,
    },
  },
  data() {
    return {
      aiCatalogFlow: {},
      activeVersionKey: null,
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
          hasGroup: Boolean(this.rootGroupId),
          groupId: convertToGraphQLId(TYPENAME_GROUP, this.rootGroupId || '0'),
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
      return !this.aiCatalogFlow.configurationForProject;
    },
    hasParentConsumer() {
      return this.aiCatalogFlow?.configurationForGroup?.enabled;
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

      const flow = this.aiCatalogFlow;
      const hasPermissions = Boolean(
        flow.configurationForProject.userPermissions?.adminAiCatalogItemConsumer,
      );
      const latestVersion = getByVersionKey(flow, VERSION_LATEST).humanVersionName;
      const pinnedVersion = getByVersionKey(flow, VERSION_PINNED).humanVersionName;

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
      v-else-if="isFlowNotFound"
      :title="s__('AICatalog|Flow not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view
      v-else
      :ai-catalog-flow="aiCatalogFlow"
      :version="version"
      :has-parent-consumer="hasParentConsumer"
    />
  </div>
</template>
