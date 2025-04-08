<script>
import { GlLink, GlLoadingIcon, GlTable, GlFormCheckbox } from '@gitlab/ui';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getNamespaceProjectsWithNamespacesQuery from 'ee/graphql_shared/queries/get_namespace_projects_with_namespaces.query.graphql';
import { i18n } from '../constants';
import Pagination from '../../../shared/pagination.vue';
import EditSection from './edit_section.vue';

export default {
  components: {
    EditSection,
    GlLink,
    GlLoadingIcon,
    GlTable,
    VisibilityIconButton,
    GlFormCheckbox,
    Pagination,
  },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
    namespacePath: {
      type: String,
      required: true,
      validator(value) {
        return /^[a-zA-Z0-9_.-]+(\/[a-zA-Z0-9_.-]+)*$/.test(value);
      },
    },
  },
  data() {
    return {
      projectList: [],
      associatedProjects: this.complianceFramework?.projects?.nodes || [],
      projectIdsToAdd: new Set(),
      projectIdsToRemove: new Set(),
      initialProjectIds: new Set(),
      errorMessage: null,
      originalProjectsLength: this.complianceFramework?.projects?.nodes?.length || 0,
      pageInfo: {},
      perPage: 20,
      isLoading: false,
    };
  },
  computed: {
    pageAllSelected() {
      return (
        this.projectList.length > 0 &&
        this.projectList.every((project) => this.projectSelected(project.id))
      );
    },
    pageAllSelectedIndeterminate() {
      const selectedOnCurrentPage = this.projectList.filter((project) =>
        this.projectSelected(project.id),
      ).length;
      return (
        this.projectList.length > 0 &&
        selectedOnCurrentPage > 0 &&
        selectedOnCurrentPage < this.projectList.length
      );
    },
    queryVariables() {
      return {
        fullPath: this.namespacePath,
        first: this.perPage,
      };
    },
    selectedCount() {
      let count = this.initialProjectIds.size;

      for (const id of this.projectIdsToRemove) {
        if (this.initialProjectIds.has(id)) {
          count -= 1;
        }
      }

      for (const id of this.projectIdsToAdd) {
        if (!this.initialProjectIds.has(id) && !this.projectIdsToRemove.has(id)) {
          count += 1;
        }
      }

      return count;
    },
  },
  watch: {
    associatedProjects: {
      immediate: true,
      handler(projects) {
        if (projects.length) {
          const projectIds = projects.map((project) => project.id);
          this.initialProjectIds = new Set(projectIds);
          this.projectIdsToAdd = new Set();
          this.projectIdsToRemove = new Set();
        }
      },
    },
  },
  apollo: {
    projectList: {
      query: getNamespaceProjectsWithNamespacesQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        this.errorMessage = null;
        this.pageInfo = data?.group?.projects?.pageInfo;
        return data?.group?.projects?.nodes || [];
      },
      error(error) {
        this.errorMessage = i18n.fetchProjectsError;
        Sentry.captureException(error);
      },
      loadingKey: 'isLoading',
    },
  },
  methods: {
    togglePageProjects(checked) {
      this.projectList.forEach((project) => {
        this.toggleProject(project.id, checked);
      });

      this.$emit('update:projects', {
        addProjects: [...this.projectIdsToAdd].map((id) => getIdFromGraphQLId(id)),
        removeProjects: [...this.projectIdsToRemove].map((id) => getIdFromGraphQLId(id)),
      });
    },
    toggleProject(projectId, checked) {
      if (checked) {
        this.projectIdsToRemove = new Set(
          [...this.projectIdsToRemove].filter((id) => id !== projectId),
        );
        this.projectIdsToAdd = new Set([...this.projectIdsToAdd, projectId]);
      } else {
        this.projectIdsToAdd = new Set([...this.projectIdsToAdd].filter((id) => id !== projectId));
        this.projectIdsToRemove = new Set([...this.projectIdsToRemove, projectId]);
      }

      this.$emit('update:projects', {
        addProjects: [...this.projectIdsToAdd].map((id) => getIdFromGraphQLId(id)),
        removeProjects: [...this.projectIdsToRemove].map((id) => getIdFromGraphQLId(id)),
      });
    },
    projectSelected(projectId) {
      return (
        (this.associatedProjects.some((project) => project.id === projectId) &&
          !this.projectIdsToRemove.has(projectId)) ||
        this.projectIdsToAdd.has(projectId)
      );
    },
    handlePreviousPage(cursor) {
      this.$apollo.queries.projectList.fetchMore({
        variables: {
          fullPath: this.namespacePath,
          first: null,
          after: null,
          last: this.perPage,
          before: cursor,
          search: null,
        },
        updateQuery: (previousResult, { fetchMoreResult }) => fetchMoreResult,
      });
    },
    handleNextPage(cursor) {
      this.$apollo.queries.projectList.fetchMore({
        variables: {
          fullPath: this.namespacePath,
          first: this.perPage,
          after: cursor,
          last: null,
          before: null,
          search: null,
        },
        updateQuery: (previousResult, { fetchMoreResult }) => fetchMoreResult,
      });
    },
    handlePageSizeChange(newSize) {
      this.perPage = newSize;
      this.$apollo.queries.projectList.refetch();
    },
  },
  tableFields: [
    {
      key: 'selected',
      label: '',
      thClass: '!gl-border-t-0 !gl-pr-0',
      tdClass: '!gl-bg-white !gl-border-b-white !gl-pr-0',
      thAttr: { width: '1%' },
      tdAttr: { width: '1%' },
    },
    {
      key: 'name',
      label: i18n.projectsTableFields.name,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
    {
      key: 'subgroup',
      label: i18n.projectsTableFields.subgroup,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.projectsTableFields.description,
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default !gl-border-b-white',
    },
  ],
  i18n,
  ROUTE_PROJECTS,
};
</script>

<template>
  <edit-section
    :title="$options.i18n.projects"
    :description="$options.i18n.projectsDescription"
    :items-count="originalProjectsLength"
  >
    <div v-if="errorMessage" class="gl-p-5 gl-text-center">
      {{ errorMessage }}
    </div>
    <div v-else>
      <div class="gl-mb-0 gl-ml-6">
        <span class="gl-font-bold" data-testid="selected-count"> {{ selectedCount }}</span>
        {{ $options.i18n.selectedCount }}
      </div>
      <gl-table
        ref="projectsTable"
        class="gl-mb-6"
        :items="projectList"
        :fields="$options.tableFields"
        responsive
        stacked="md"
        hover
        select-mode="single"
        selected-variant="primary"
      >
        <template #head(selected)>
          <gl-form-checkbox
            class="gl-m-0"
            data-testid="select-all-checkbox"
            :indeterminate="pageAllSelectedIndeterminate"
            :checked="pageAllSelected"
            @change="togglePageProjects"
          />
        </template>
        <template #cell(selected)="{ item }">
          <gl-form-checkbox
            class="gl-m-0"
            :checked="projectSelected(item.id)"
            @change="toggleProject(item.id, $event)"
          />
        </template>
        <template #cell(name)="{ item }">
          <gl-link data-testid="project-link" :href="item.webUrl">{{ item.name }}</gl-link>
          <visibility-icon-button
            v-if="item.visibility"
            class="gl-ml-2"
            :visibility-level="item.visibility"
          />
        </template>
        <template #cell(subgroup)="{ item }">
          <gl-link v-if="item.namespace" data-testid="subgroup-link" :href="item.namespace.webUrl">
            {{ item.namespace.fullName }}
          </gl-link>
        </template>
        <template #cell(description)="{ item }">
          {{ item.description }}
        </template>

        <template #table-busy>
          <gl-loading-icon size="lg" />
        </template>

        <template #empty>
          <div class="gl-p-5">
            {{ $options.i18n.noProjects }}
          </div>
        </template>
      </gl-table>

      <pagination
        v-if="pageInfo"
        :page-info="pageInfo"
        :is-loading="isLoading"
        :per-page="perPage"
        @prev="handlePreviousPage"
        @next="handleNextPage"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </edit-section>
</template>
