<script>
import { GlLink, GlLoadingIcon, GlTable, GlFormCheckbox } from '@gitlab/ui';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getNamespaceProjectsWithNamespacesQuery from 'ee/graphql_shared/queries/get_namespace_projects_with_namespaces.query.graphql';
import { i18n } from '../constants';
import EditSection from './edit_section.vue';

export default {
  components: {
    EditSection,
    GlLink,
    GlLoadingIcon,
    GlTable,
    VisibilityIconButton,
    GlFormCheckbox,
  },
  props: {
    complianceFramework: {
      type: Object,
      required: true,
    },
    namespacePath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      projectList: [],
      projectIdsToAdd: new Set(),
      projectIdsToRemove: new Set(),
      initialProjectIds: new Set(),
      errorMessage: null,
      originalProjectsLength: this.complianceFramework?.projects?.nodes?.length || 0,
    };
  },
  computed: {
    associatedProjects() {
      return this.complianceFramework?.projects?.nodes || [];
    },
    allSelected() {
      return this.projectList.length > 0 && this.projectIdsToAdd.size === this.projectList.length;
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
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        this.errorMessage = null;
        return data?.group?.projects?.nodes || [];
      },
      error(error) {
        this.errorMessage = i18n.fetchProjectsError;
        Sentry.captureException(error);
      },
      loadingKey: 'loading',
    },
  },
  methods: {
    toggleAllProjects(checked) {
      if (checked) {
        this.projectList.forEach((project) => {
          this.projectIdsToAdd.add(project.id);
        });
        this.projectIdsToRemove.clear();
      } else {
        this.projectList.forEach((project) => {
          this.projectIdsToRemove.add(project.id);
        });
        this.projectIdsToAdd.clear();
      }

      this.$emit('update:projects', {
        addProjects: [...this.projectIdsToAdd].map((id) => getIdFromGraphQLId(id)),
        removeProjects: [...this.projectIdsToRemove].map((id) => getIdFromGraphQLId(id)),
      });
    },
    toggleProject(projectId, checked) {
      if (checked) {
        this.projectIdsToRemove.delete(projectId);
        this.projectIdsToAdd.add(projectId);
      } else {
        this.projectIdsToAdd.delete(projectId);
        this.projectIdsToRemove.add(projectId);
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
    <gl-table
      v-else
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
        <gl-form-checkbox class="gl-m-0" :checked="allSelected" @change="toggleAllProjects" />
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
  </edit-section>
</template>
