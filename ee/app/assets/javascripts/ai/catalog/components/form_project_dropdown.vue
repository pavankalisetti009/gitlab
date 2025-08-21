<script>
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import produce from 'immer';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import { ACCESS_LEVEL_MAINTAINER_STRING } from '~/access_level/constants';
import getProjects from '~/graphql_shared/queries/get_users_projects.query.graphql';
import { AVATAR_SHAPE_OPTION_RECT } from '~/vue_shared/constants';

const MINIMUM_QUERY_LENGTH = 3;
const PROJECTS_PER_PAGE = 20;

export default {
  name: 'FormProjectDropdown',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isLoadingInitial: true,
      isLoadingMore: false,
      projects: [],
      projectSearchQuery: '',
    };
  },
  apollo: {
    projects: {
      query: getProjects,
      variables() {
        return {
          ...this.queryVariables,
        };
      },
      skip() {
        return this.isSearchQueryTooShort;
      },
      update(data) {
        return data?.projects || [];
      },
      result() {
        this.isLoadingInitial = false;
      },
      error() {
        this.onError();
      },
    },
  },
  computed: {
    queryVariables() {
      return {
        first: PROJECTS_PER_PAGE,
        minAccessLevel: ACCESS_LEVEL_MAINTAINER_STRING,
        search: this.projectSearchQuery,
        sort: 'similarity',
      };
    },
    isLoading() {
      return this.$apollo.queries.projects.loading && !this.isLoadingMore;
    },
    isSearchQueryTooShort() {
      return this.projectSearchQuery && this.projectSearchQuery.length < MINIMUM_QUERY_LENGTH;
    },
    noResultsText() {
      return this.isSearchQueryTooShort
        ? __('Enter at least three characters to search')
        : __('No results found');
    },
    selectedProject() {
      return this.projects?.nodes?.find((project) => this.value === project.id);
    },
    projectDropdownText() {
      return this.selectedProject?.nameWithNamespace || __('Select a project');
    },
    projectList() {
      if (this.isSearchQueryTooShort) {
        return [];
      }

      return (this.projects?.nodes || []).map((project) => ({
        ...project,
        text: project.nameWithNamespace,
        value: String(project.id),
      }));
    },
    hasNextPage() {
      return this.projects?.pageInfo?.hasNextPage;
    },
  },
  methods: {
    async onBottomReached() {
      if (!this.hasNextPage) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.projects.fetchMore({
          variables: {
            ...this.queryVariables,
            after: this.projects.pageInfo?.endCursor,
          },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            return produce(fetchMoreResult, (draftData) => {
              draftData.projects.nodes = [
                ...previousResult.projects.nodes,
                ...draftData.projects.nodes,
              ];
            });
          },
        });
      } catch (error) {
        this.onError();
      } finally {
        this.isLoadingMore = false;
      }
    },
    onError() {
      this.$emit('error', __('Failed to load projects'));
    },
    onSearch: debounce(function debouncedSearch(query) {
      this.projectSearchQuery = query;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onProjectSelect(projectId) {
      this.$emit('input', projectId);
    },
  },
  AVATAR_SHAPE_OPTION_RECT,
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="value"
    :items="projectList"
    :toggle-id="id"
    :toggle-text="projectDropdownText"
    :header-text="__('Select a project')"
    :loading="isLoadingInitial"
    searchable
    :searching="isLoading"
    :no-results-text="noResultsText"
    block
    fluid-width
    is-check-centered
    :infinite-scroll="hasNextPage"
    :infinite-scroll-loading="isLoadingMore"
    data-testid="project-select"
    @bottom-reached="onBottomReached"
    @search="onSearch"
    @select="onProjectSelect"
  >
    <template #list-item="{ item: project }">
      <gl-avatar-labeled
        v-if="project"
        :shape="$options.AVATAR_SHAPE_OPTION_RECT"
        :size="32"
        :src="project.avatarUrl"
        :label="project.name"
        :entity-name="project.name"
        :sub-label="project.nameWithNamespace"
      />
    </template>
  </gl-collapsible-listbox>
</template>
