<script>
import {
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlIcon,
  GlLoadingIcon,
  GlIntersperse,
  GlIntersectionObserver,
} from '@gitlab/ui';
import produce from 'immer';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getProjectComponentVersions from 'ee/dependencies/graphql/project_component_versions.query.graphql';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlIcon,
    GlLoadingIcon,
    GlIntersperse,
    GlIntersectionObserver,
  },
  inject: ['projectFullPath'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      versions: [],
      selectedVersionIds: [],
      pageInfo: {},
    };
  },
  apollo: {
    versions: {
      query: getProjectComponentVersions,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.namespace.componentVersions.nodes.map(({ version, id }) => ({
          version,
          id: getIdFromGraphQLId(id),
        }));
      },
      result({ data }) {
        this.pageInfo = data?.namespace.componentVersions.pageInfo || {};
      },
      skip() {
        return this.noSelectedComponent || this.multipleSelectedComponents;
      },
      error() {
        this.showError();
      },
    },
  },
  computed: {
    ...mapState('allDependencies', ['componentIds']),
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedVersionIds,
      };
    },
    queryVariables() {
      return {
        componentId: this.componentIds?.[0],
        fullPath: this.projectFullPath,
      };
    },
    noSelectedComponent() {
      return this.componentIds.length === 0;
    },
    multipleSelectedComponents() {
      return this.componentIds.length > 1;
    },
    viewOnly() {
      return this.noSelectedComponent || this.multipleSelectedComponents;
    },
    isLoading() {
      return this.$apollo.queries.versions.loading;
    },
    selectedVersions() {
      return this.versions.filter(({ id }) => this.isVersionSelected(id));
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
  },
  methods: {
    isVersionSelected(id) {
      return this.selectedVersionIds.includes(id);
    },
    toggleSelectedVersion(id) {
      if (this.isVersionSelected(id)) {
        this.selectedVersionIds = this.selectedVersionIds.filter((versionId) => versionId !== id);
      } else {
        this.selectedVersionIds.push(id);
      }
    },
    bottomReached() {
      if (this.isLoading) return;

      const variables = {
        after: this.pageInfo.endCursor,
        ...this.queryVariables,
      };

      this.$apollo.queries.versions
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              draftData.namespace.componentVersions.nodes = [
                ...previousResult.namespace.componentVersions.nodes,
                ...draftData.namespace.componentVersions.nodes,
              ];
            });
          },
        })
        .catch(this.showError);
    },
    showError() {
      createAlert({
        message: s__(
          'Dependencies|There was an error fetching the versions for the selected component. Please try again later.',
        ),
      });
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedVersionIds"
    :value="tokenValue"
    :view-only="viewOnly"
    v-on="$listeners"
    @select="toggleSelectedVersion"
  >
    <template #view>
      <gl-intersperse data-testid="selected-versions">
        <span v-for="{ id, version } in selectedVersions" :key="id">{{ version }}</span>
      </gl-intersperse>
    </template>
    <template #suggestions>
      <div v-if="noSelectedComponent" class="gl-p-2 gl-text-secondary">
        {{ s__('Dependencies|To filter by version, filter by one component first') }}
      </div>
      <div v-else-if="multipleSelectedComponents" class="gl-p-2 gl-text-secondary">
        {{ s__('Dependencies|To filter by version, select exactly one component first') }}
      </div>
      <template v-else>
        <gl-filtered-search-suggestion v-for="{ version, id } in versions" :key="id" :value="id">
          <div class="gl-flex gl-items-center">
            <gl-icon
              name="check"
              class="gl-mr-3 gl-shrink-0 gl-text-gray-700"
              :class="{
                'gl-invisible': !isVersionSelected(id),
              }"
            />
            {{ version }}
          </div>
        </gl-filtered-search-suggestion>
        <gl-loading-icon v-if="isLoading" size="sm" />
        <gl-intersection-observer v-if="hasNextPage" @appear="bottomReached" />
      </template>
    </template>
  </gl-filtered-search-token>
</template>
