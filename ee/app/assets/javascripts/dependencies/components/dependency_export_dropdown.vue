<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import {
  EXPORT_FORMATS,
  NAMESPACE_GROUP,
  NAMESPACE_ORGANIZATION,
  NAMESPACE_PROJECT,
} from '../constants';

const exportFormats = [
  {
    type: EXPORT_FORMATS.dependencyList,
    buttonText: s__('Dependencies|Export as JSON'),
    availableFor: [NAMESPACE_PROJECT],
    testid: 'dependency-list-item',
  },
  {
    type: EXPORT_FORMATS.jsonArray,
    buttonText: s__('Dependencies|Export as JSON'),
    availableFor: [NAMESPACE_GROUP],
    testid: 'json-array-item',
  },
  {
    type: EXPORT_FORMATS.csv,
    buttonText: s__('Dependencies|Export as CSV'),
    availableFor: [NAMESPACE_PROJECT, NAMESPACE_GROUP, NAMESPACE_ORGANIZATION],
    testid: 'csv-item',
  },
];

export default {
  name: 'DependencyExportDropdown',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    container: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['currentList']),
    ...mapState({
      fetchingInProgress(state) {
        return state[this.currentList].fetchingInProgress;
      },
    }),
    availableFormats() {
      return exportFormats.filter((format) => format.availableFor.includes(this.container));
    },
    multipleFormats() {
      return this.availableFormats.length > 1;
    },
    singleFormat() {
      return this.availableFormats[0];
    },
    exportButtonIcon() {
      return this.fetchingInProgress ? '' : 'export';
    },
  },
  methods: {
    ...mapActions({
      createExport(dispatch, type) {
        return dispatch(`${this.currentList}/fetchExport`, { export_type: type });
      },
    }),
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    v-if="multipleFormats"
    :icon="exportButtonIcon"
    :loading="fetchingInProgress"
    :toggle-text="__('Export')"
    data-testid="export-disclosure"
  >
    <gl-disclosure-dropdown-item
      v-for="format in availableFormats"
      :key="format.type"
      :data-testid="format.testid"
      @action="createExport(format.type)"
    >
      <template #list-item>
        {{ format.buttonText }}
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>

  <gl-button
    v-else
    v-gl-tooltip.hover
    :title="singleFormat.buttonText"
    class="gl-mt-3 md:gl-mt-0"
    :icon="exportButtonIcon"
    :loading="fetchingInProgress"
    @click="createExport(singleFormat.type)"
  >
    {{ __('Export') }}
  </gl-button>
</template>
