<script>
import Vue from 'vue';
import {
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlTable,
  GlToast,
  GlLink,
  GlAlert,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import FrameworkBadge from '../shared/framework_badge.vue';
import { ROUTE_EDIT_FRAMEWORK, CREATE_FRAMEWORKS_DOCS_URL } from '../../constants';
import { isTopLevelGroup, convertFrameworkIdToGraphQl } from '../../utils';
import FrameworkInfoDrawer from './framework_info_drawer.vue';
import DeleteModal from './edit_framework/components/delete_modal.vue';

Vue.use(GlToast);

export default {
  name: 'FrameworksTable',
  components: {
    GlLoadingIcon,
    GlSearchBoxByClick,
    GlTable,
    GlLink,
    GlAlert,
    FrameworkInfoDrawer,
    FrameworkBadge,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    DeleteModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
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
  data() {
    return {
      frameworkToDeleteName: null,
      frameworkToDeleteID: null,
    };
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
    showNoFrameworksAlert() {
      return !this.frameworks.length && !this.isLoading && !this.isTopLevelGroup;
    },
  },
  methods: {
    getIdFromGraphQLId,
    toggleDrawer(item) {
      if (this.selectedFramework?.id === item.id) {
        this.closeDrawer();
      } else {
        this.openDrawer(item);
      }
    },
    copyFrameworkId(id) {
      navigator?.clipboard?.writeText(getIdFromGraphQLId(id));
      this.$toast.show(this.$options.i18n.copyIdToastText);
    },
    showDeleteModal(framework) {
      this.frameworkToDeleteName = framework.name;
      this.frameworkToDeleteId = framework.id;
      this.$refs.deleteModal.show();
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
    {
      key: 'action',
      label: __('Action'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
  ],
  i18n: {
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),
    noFrameworksText: s__(
      'ComplianceFrameworks|No frameworks found. Create a framework in top-level group',
    ),
    learnMore: __('Learn more'),
    copyIdToastText: s__('ComplianceFrameworksReport|Framework ID copied to clipboard.'),
    actionCopyId: s__('ComplianceFrameworksReport|Copy ID'),
    copyIdExplanation: s__(
      'ComplianceFrameworksReport|Use the compliance framework ID in configuration or API requests.',
    ),
    actionEdit: __('Edit'),
    actionDelete: __('Delete'),
    toggleText: __('Actions for'),
  },
  CREATE_FRAMEWORKS_DOCS_URL,
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
    <gl-alert
      v-if="showNoFrameworksAlert"
      variant="info"
      data-testid="no-frameworks-alert"
      :dismissible="false"
    >
      <div>
        {{ $options.i18n.noFrameworksText }}
        <gl-link :href="rootAncestor.complianceCenterPath"> {{ rootAncestor.name }}</gl-link
        >.
        <gl-link :href="$options.CREATE_FRAMEWORKS_DOCS_URL"
          >{{ $options.i18n.learnMore }}.</gl-link
        >
      </div>
    </gl-alert>
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
      <template #cell(action)="{ item }">
        <gl-disclosure-dropdown
          icon="ellipsis_v"
          :toggle-text="`${$options.i18n.toggleText} ${item.name}`"
          text-sr-only
          category="tertiary"
          placement="bottom-end"
          no-caret
        >
          <template v-if="isTopLevelGroup">
            <gl-disclosure-dropdown-item
              data-testid="edit-action"
              @action="editFramework({ id: item.id })"
            >
              <template #list-item>
                {{ $options.i18n.actionEdit }}
              </template>
            </gl-disclosure-dropdown-item>
            <gl-disclosure-dropdown-item
              data-testid="delete-action"
              @action="showDeleteModal(item)"
            >
              <template #list-item>
                {{ $options.i18n.actionDelete }}
              </template>
            </gl-disclosure-dropdown-item>
          </template>
          <gl-disclosure-dropdown-item
            v-gl-tooltip.left.viewport
            data-testid="copy-id-action"
            :title="$options.i18n.copyIdExplanation"
            @action="copyFrameworkId(item.id)"
          >
            <template #list-item>
              {{ $options.i18n.actionCopyId }}: {{ getIdFromGraphQLId(item.id) }}
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown>
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
    <delete-modal
      ref="deleteModal"
      :name="frameworkToDeleteName || ''"
      @delete="$emit('delete-framework', frameworkToDeleteId)"
    />
  </section>
</template>
