<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { UNKNOWN_LICENSE } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

export default {
  i18n: {
    selectedLabel: __('Selected'),
    licenses: __('Licenses'),
    header: s__('ScanResultPolicy|Choose a license'),
  },
  name: 'DenyAllowLicenses',
  components: {
    GlCollapsibleListbox,
  },
  inject: ['parsedSoftwareLicenses'],
  props: {
    selected: {
      type: Object,
      required: false,
      default: undefined,
    },
  },
  computed: {
    allLicenses() {
      return [UNKNOWN_LICENSE, ...this.parsedSoftwareLicenses];
    },
    licenses() {
      const groups = [
        {
          text: this.$options.i18n.licenses,
          options: this.allLicenses,
        },
      ];

      if (this.selected) {
        groups.unshift({
          text: this.$options.i18n.selectedLabel,
          options: [this.selected],
        });
      }

      return groups;
    },
    selectedItem() {
      return this.selected?.value || '';
    },
    toggleText() {
      return this.selected?.text || this.$options.i18n.header;
    },
  },
  methods: {
    selectLicense(id) {
      const license = this.allLicenses.find((item) => item.value === id);
      this.$emit('select', license);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="$options.i18n.header"
    :items="licenses"
    :toggle-text="toggleText"
    :selected="selectedItem"
    size="small"
    searchable
    @select="selectLicense"
  />
</template>
