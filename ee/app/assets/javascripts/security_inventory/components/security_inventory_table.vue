<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ProjectAttributesUpdateDrawer from 'ee_component/security_configuration/security_attributes/components/project_attributes_update_drawer.vue';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';
import AttributesCell from './attributes_cell.vue';

const SKELETON_ROW_COUNT = 3;

export default {
  components: {
    GlTableLite,
    GlSkeletonLoader,
    NameCell,
    VulnerabilityCell,
    ToolCoverageCell,
    ActionCell,
    AttributesCell,
    ProjectAttributesUpdateDrawer,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canReadAttributes'],
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasSearch: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      selectedProject: null,
    };
  },
  computed: {
    displayItems() {
      return this.isLoading && this.items.length === 0
        ? Array(SKELETON_ROW_COUNT).fill({})
        : this.items;
    },
    fields() {
      const fields = [
        { key: 'name', label: __('Name'), thClass: 'gl-max-w-0' },
        { key: 'vulnerabilities', label: __('Vulnerabilities'), thClass: 'gl-w-1/5' },
        { key: 'toolCoverage', label: __('Tool Coverage'), thClass: 'gl-w-1/3' },
        // spliced element gets inserted here
        { key: 'actions', label: '', thClass: 'gl-w-2/20' },
      ];
      if (this.glFeatures.securityContextLabels && this.canReadAttributes) {
        fields.splice(3, 0, {
          key: 'securityAttributes',
          label: s__('SecurityAttributes|Security attributes'),
          thClass: 'gl-w-1/6',
        });
      }
      return fields;
    },
  },
  methods: {
    openAttributesDrawer(item) {
      this.selectedProject = item;
      this.$nextTick(() => {
        this.$refs.attributesDrawer.openDrawer();
      });
    },

    refreshDashboard() {
      this.$emit('saved');
    },
  },
};
</script>

<template>
  <div>
    <gl-table-lite :items="displayItems" :fields="fields" hover table-class="gl-table-fixed">
      <template #cell(name)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="200" :height="20" preserve-aspect-ratio="none">
          <rect x="0" y="5" width="15" height="15" rx="3" />
          <rect x="24" y="5" width="50" height="5" rx="2" />
          <rect x="24" y="15" width="100" height="5" rx="2" />
        </gl-skeleton-loader>
        <name-cell v-else :item="item" :show-search-param="hasSearch" />
      </template>

      <template #cell(vulnerabilities)="{ item, index }">
        <gl-skeleton-loader v-if="isLoading" :width="250" :height="20">
          <rect x="0" y="6" width="230" height="13" rx="6" />
        </gl-skeleton-loader>
        <vulnerability-cell v-else :item="item" :index="index" />
      </template>

      <template #cell(toolCoverage)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="300" :height="30" preserve-aspect-ratio="none">
          <rect x="0" y="5" width="32" height="20" rx="10" />
          <rect x="38" y="5" width="32" height="20" rx="10" />
          <rect x="76" y="5" width="32" height="20" rx="10" />
          <rect x="114" y="5" width="32" height="20" rx="10" />
          <rect x="152" y="5" width="32" height="20" rx="10" />
          <rect x="190" y="5" width="32" height="20" rx="10" />
        </gl-skeleton-loader>
        <tool-coverage-cell v-else :item="item" />
      </template>

      <template #cell(securityAttributes)="{ item, index }">
        <gl-skeleton-loader v-if="isLoading" :width="250" :height="40">
          <rect x="0" y="5" width="100" height="15" rx="6" />
          <rect x="105" y="5" width="100" height="15" rx="6" />
          <rect x="0" y="25" width="100" height="15" rx="6" />
        </gl-skeleton-loader>
        <attributes-cell
          v-else
          :index="index"
          :item="item"
          @openAttributesDrawer="openAttributesDrawer"
        />
      </template>

      <template #cell(actions)="{ item }">
        <gl-skeleton-loader v-if="isLoading" :width="32" :height="18">
          <rect x="0" y="3" width="12" height="12" rx="2" />
        </gl-skeleton-loader>
        <action-cell v-else :item="item" @openAttributesDrawer="openAttributesDrawer" />
      </template>
    </gl-table-lite>
    <project-attributes-update-drawer
      v-if="selectedProject"
      :key="selectedProject.id"
      ref="attributesDrawer"
      :project-id="selectedProject.id"
      :selected-attributes="selectedProject.securityAttributes.nodes"
      @saved="refreshDashboard"
    />
  </div>
</template>
