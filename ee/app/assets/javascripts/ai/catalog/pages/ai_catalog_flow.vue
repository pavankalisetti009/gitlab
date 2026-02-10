<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { TYPENAME_PROJECT, TYPENAME_GROUP } from '~/graphql_shared/constants';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import aiCatalogFlowQuery from '../graphql/queries/ai_catalog_flow.query.graphql';
import { resolveVersion } from '../utils';
import { AI_CATALOG_TYPE_FLOW } from '../constants';

export default {
  name: 'AiCatalogFlow',
  components: {
    ErrorsAlert,
    GlEmptyState,
    GlLoadingIcon,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
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
      aiCatalogFlow: {},
      activeVersionKey: null,
      errors: [],
    };
  },
  apollo: {
    aiCatalogFlow: {
      query: aiCatalogFlowQuery,
      variables() {
        const hasGroup = Boolean(this.projectId ? this.rootGroupId : this.groupId);
        const groupId = this.projectId ? this.rootGroupId : this.groupId;

        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
          showSoftDeleted: !this.isGlobal,
          hasProject: Boolean(this.projectId),
          // projectId is non-nullable in GraphQL query, so we need a fallback value.
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId || '0'),
          hasGroup,
          groupId: convertToGraphQLId(TYPENAME_GROUP, groupId || '0'),
        };
      },
      // fetchPolicy needed to refresh item after updating triggers
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update(data) {
        const item = data?.aiCatalogItem || {};
        if (item.itemType !== AI_CATALOG_TYPE_FLOW) {
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
    hasParentConsumer() {
      return this.aiCatalogFlow?.configurationForGroup?.enabled;
    },
    isEnabled() {
      return this.groupId
        ? Boolean(this.aiCatalogFlow?.configurationForGroup?.enabled)
        : Boolean(this.aiCatalogFlow?.configurationForProject?.enabled);
    },
    resolvedVersion() {
      return resolveVersion(this.aiCatalogFlow, this.isGlobal);
    },
    isUpdateAvailable() {
      const latestVersion = this.aiCatalogFlow.latestVersion.versionName;
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
    aiCatalogFlow: {
      handler() {
        if (this.aiCatalogFlow?.name) {
          document.title = `${this.aiCatalogFlow.name} · ${this.baseTitle}`;
        }
      },
      deep: true,
    },
  },
  created() {
    const itemType = s__('AICatalog|Flows');
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
