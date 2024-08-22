<script>
import Vue from 'vue';
import { GlLoadingIcon, GlSearchBoxByClick, GlTable, GlToast, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import FrameworkBadge from '../shared/framework_badge.vue';
import { ROUTE_EDIT_FRAMEWORK } from '../../constants';
import { isTopLevelGroup, convertFrameworkIdToGraphQl } from '../../utils';
import FrameworkInfoDrawer from './framework_info_drawer.vue';

Vue.use(GlToast);

export default {
  name: 'FrameworksTable',
  components: {
    GlLoadingIcon,
    GlSearchBoxByClick,
    GlTable,
    GlLink,
    FrameworkInfoDrawer,
    FrameworkBadge,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
    frameworks: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },

    selectedFramework() {
      return this.$route.query.id
        ? this.frameworks.find(
            (framework) => framework.id === convertFrameworkIdToGraphQl(this.$route.query.id),
          )
        : null;
    },
    showDrawer() {
      return this.selectedFramework !== null;
    },
  },
  methods: {
    toggleDrawer(item) {
      if (this.selectedFramework?.id === item.id) {
        this.closeDrawer();
      } else {
        this.openDrawer(item);
      }
    },
    openDrawer(item) {
      this.$router.push({ query: { id: getIdFromGraphQLId(item.id) } });
    },
    closeDrawer() {
      this.$router.push({ query: null });
    },
    isLastItem(index, arr) {
      return index >= arr.length - 1;
    },
    editFramework({ id }) {
      this.$router.push({ name: ROUTE_EDIT_FRAMEWORK, params: { id: getIdFromGraphQLId(id) } });
    },
    getPoliciesList(item) {
      const { scanExecutionPolicies, scanResultPolicies } = item;
      return [...scanExecutionPolicies.nodes, ...scanResultPolicies.nodes]
        .map((x) => x.name)
        .join(',');
    },
    filterProjects(projects) {
      return projects.filter((p) => p.fullPath.startsWith(this.groupPath));
    },
  },
  fields: [
    {
      key: 'frameworkName',
      label: __('Frameworks'),
      thClass: 'md:gl-max-w-26 !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'associatedProjects',
      label: __('Associated projects'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'policies',
      label: __('Policies'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
  ],
  i18n: {
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),
  },
};
</script>
<template>
  <section>
    <div class="gl-flex gl-gap-4 gl-bg-gray-10 gl-p-4">
      <gl-search-box-by-click
        class="gl-grow"
        @submit="$emit('search', $event)"
        @clear="$emit('search', '')"
      />
    </div>
    <gl-table
      :fields="$options.fields"
      :busy="isLoading"
      :items="frameworks"
      no-local-sorting
      show-empty
      stacked="md"
      hover
      @row-clicked="toggleDrawer"
    >
      <template #cell(frameworkName)="{ item }">
        <framework-badge :framework="item" :show-edit="isTopLevelGroup" />
      </template>
      <template
        #cell(associatedProjects)="{
          item: {
            projects: { nodes: associatedProjects },
          },
        }"
      >
        <div
          v-for="(associatedProject, index) in filterProjects(associatedProjects)"
          :key="associatedProject.id"
          class="gl-inline-block"
        >
          <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link
          ><span v-if="!isLastItem(index, associatedProjects)">,&nbsp;</span>
        </div>
      </template>
      <template #cell(policies)="{ item }">
        {{ getPoliciesList(item) }}
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center">
          {{ $options.i18n.noFrameworksFound }}
        </div>
      </template>
    </gl-table>
    <framework-info-drawer
      :group-path="groupPath"
      :root-ancestor="rootAncestor"
      :framework="selectedFramework"
      @close="closeDrawer"
      @edit="editFramework"
    />
  </section>
</template>
