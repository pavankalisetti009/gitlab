<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__, __ } from '~/locale';

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
  props: {
    selected: {
      type: Object,
      required: false,
      default: undefined,
    },
    alreadySelectedLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
    allLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    allSelected() {
      return this.allLicenses.length === this.alreadySelectedLicenses.length;
    },
    unselectedLicenses() {
      const alreadySelectedValues = this.alreadySelectedLicenses.map(({ value }) => value);
      return this.allLicenses.filter(({ value }) => !alreadySelectedValues.includes(value));
    },
    licenses() {
      const groups = [];

      if (!this.allSelected) {
        groups.unshift({
          text: this.$options.i18n.licenses,
          options: this.unselectedLicenses.filter(({ value }) => value !== this.selected?.value),
        });
      }

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
