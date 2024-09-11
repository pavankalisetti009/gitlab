<script>
import { GlEmptyState, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg?url';
import GetNamespacePagesDeployments from '../graphql/pages_deployments.query.graphql';
import ProjectView from './project.vue';

export default {
  name: 'PagesProjects',
  components: {
    ProjectView,
    GlEmptyState,
    GlLoadingIcon,
    GlAlert,
  },
  EMPTY_STATE_SVG_URL,
  inject: ['fullPath'],
  props: {
    sort: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      projects: {},
      resultsPerPage: 15,
      error: null,
    };
  },
  apollo: {
    projects: {
      query: GetNamespacePagesDeployments,
      variables() {
        return {
          fullPath: this.fullPath,
          first: this.resultsPerPage,
          sort: this.sort,
          active: true,
          versioned: true,
        };
      },
      update(data) {
        return data.namespace.projects.nodes.filter(
          (project) => project.pagesDeployments.count > 0,
        );
      },
      error(error) {
        this.error = error;
      },
    },
  },
  computed: {
    hasResults() {
      return this.projects?.length;
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="$apollo.loading" size="lg" />
    <gl-alert v-else-if="error" variant="danger" :dismissible="false" icon="error">
      {{ s__('Pages|An error occurred trying to load the Pages deployments.') }}
    </gl-alert>
    <gl-empty-state
      v-else-if="!hasResults"
      :title="__('No projects found')"
      :description="
        s__('Pages|We did not find any projects with parallel Pages deployments in this namespace.')
      "
      :svg-path="$options.EMPTY_STATE_SVG_URL"
    />
    <div v-else class="gl-flex gl-flex-col gl-gap-4">
      <project-view v-for="node in projects" :key="node.id" :project="node" />
    </div>
  </div>
</template>
