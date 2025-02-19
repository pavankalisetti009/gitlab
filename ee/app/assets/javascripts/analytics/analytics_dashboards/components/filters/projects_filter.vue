<script>
import ProjectsDropdownFilter from '~/analytics/shared/components/projects_dropdown_filter.vue';

export default {
  components: {
    ProjectsDropdownFilter,
  },
  props: {
    groupNamespace: {
      type: String,
      required: true,
    },
  },
  computed: {
    queryParams() {
      return {
        first: 50,
        includeSubgroups: true,
      };
    },
  },
  methods: {
    onProjectsSelected(selectedProjects) {
      const projectNamespace = selectedProjects[0]?.fullPath || null;
      const projectId = selectedProjects[0]?.id || null;
      if (projectId && projectNamespace) {
        this.$emit('projectSelected', {
          projectNamespace,
          projectId,
        });
      }
    },
  },
};
</script>

<template>
  <projects-dropdown-filter
    :key="groupNamespace"
    toggle-classes="gl-max-w-26"
    :query-params="queryParams"
    :group-namespace="groupNamespace"
    :use-graphql="true"
    @selected="onProjectsSelected"
  />
</template>
