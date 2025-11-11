<script>
import { GlTableLite, GlSkeletonLoader, GlFormCheckbox, GlTooltipDirective } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ProjectAttributesUpdateDrawer from 'ee_component/security_configuration/security_attributes/components/project_attributes_update_drawer.vue';
import BulkAttributesUpdateDrawer from 'ee_component/security_configuration/security_attributes/components/bulk_attributes_update_drawer.vue';
import { MAX_SELECTED_COUNT } from '../constants';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';
import AttributesCell from './attributes_cell.vue';
import CheckboxCell from './checkbox_cell.vue';

const SKELETON_ROW_COUNT = 3;

export default {
  components: {
    GlTableLite,
    GlSkeletonLoader,
    GlFormCheckbox,
    NameCell,
    VulnerabilityCell,
    ToolCoverageCell,
    ActionCell,
    AttributesCell,
    CheckboxCell,
    ProjectAttributesUpdateDrawer,
    BulkAttributesUpdateDrawer,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canReadAttributes', 'canManageAttributes'],
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
      selectedItems: [],
    };
  },
  computed: {
    displayItems() {
      return this.isLoading && this.items.length === 0
        ? Array(SKELETON_ROW_COUNT).fill({})
        : this.items;
    },
    shouldShowBulkEdit() {
      return (
        this.glFeatures.securityContextLabels &&
        this.glFeatures.bulkEditSecurityAttributes &&
        this.canManageAttributes
      );
    },
    isAnyItemSelected() {
      return this.items.some((item) => this.isSelected(item));
    },
    areAllItemsSelected() {
      return this.items.every((item) => this.isSelected(item));
    },
    isSelectedLimitReached() {
      return this.selectedItems.length >= MAX_SELECTED_COUNT;
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
        if (this.shouldShowBulkEdit) {
          fields.splice(0, 0, {
            key: 'checkbox',
            label: '',
            thClass: 'gl-w-0',
            tdClass: '!gl-align-middle',
          });
        }
      }
      return fields;
    },
  },
  methods: {
    isSelected(item) {
      return this.selectedItems.includes(item.id);
    },
    selectItem(item, checked) {
      if (checked) {
        this.selectedItems.push(item.id);
      } else {
        this.selectedItems = this.selectedItems.filter(
          (selectedItemId) => selectedItemId !== item.id,
        );
      }
      this.$emit('selectedCount', this.selectedItems.length);
    },
    selectAll(selected) {
      if (selected) {
        this.selectedItems = [...this.items.map((item) => item.id)].slice(0, MAX_SELECTED_COUNT);
      } else {
        this.selectedItems = [];
      }
      this.$emit('selectedCount', this.selectedItems.length);
    },
    // eslint-disable-next-line vue/no-unused-properties
    clearSelection() {
      this.selectAll(false);
    },
    // eslint-disable-next-line vue/no-unused-properties
    bulkEdit() {
      this.$nextTick(() => {
        this.$refs.bulkAttributesDrawer.openDrawer();
      });
    },
    openAttributesDrawer(item) {
      this.selectedProject = item;
      this.$nextTick(() => {
        this.$refs.attributesDrawer.openDrawer();
      });
    },
    refreshDashboard() {
      this.$emit('refetch');
    },
  },
};
</script>

<template>
  <div>
    <gl-table-lite :items="displayItems" :fields="fields" hover table-class="gl-table-fixed">
      <template v-if="shouldShowBulkEdit" #head(checkbox)>
        <gl-form-checkbox
          v-gl-tooltip.right
          :title="__('Select all items')"
          :checked="isAnyItemSelected"
          :indeterminate="isAnyItemSelected && !areAllItemsSelected"
          :disabled="isLoading"
          class="gl-min-h-4"
          @change="selectAll"
        />
      </template>

      <template v-if="shouldShowBulkEdit" #cell(checkbox)="{ item }">
        <checkbox-cell
          v-if="!isLoading"
          :item="item"
          :is-selected="isSelected(item)"
          :is-selected-limit-reached="isSelectedLimitReached"
          @selectItem="selectItem"
        />
      </template>

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
      ref="attributesDrawer"
      :project-id="selectedProject.id"
      :selected-attributes="selectedProject.securityAttributes.nodes"
      @saved="refreshDashboard"
    />
    <bulk-attributes-update-drawer
      v-if="selectedItems.length"
      ref="bulkAttributesDrawer"
      :item-ids="selectedItems"
      @refetch="refreshDashboard"
    />
  </div>
</template>
