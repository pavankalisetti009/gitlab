<script>
import { debounce } from 'lodash';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';

export default {
  i18n: {
    defaultText: s__('SecurityOrchestration|Select a variable'),
  },
  name: 'VariablesSelector',
  components: {
    GlCollapsibleListbox,
    SectionLayout,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: '',
    },
    alreadySelectedItems: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    items() {
      const items = FLAT_LIST_OPTIONS.filter(
        (value) => !this.alreadySelectedItems.includes(value),
      ).map((item) => ({ text: item, value: item }));

      return searchInItemsProperties({
        items,
        properties: ['value'],
        searchQuery: this.searchTerm,
      });
    },
    toggleText() {
      if (!FLAT_LIST_OPTIONS.includes(this.selected)) {
        return this.$options.i18n.defaultText;
      }

      return this.selected;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    selectVariable(variable) {
      this.$emit('select', variable);
    },
    setSearchTerm(searchTerm) {
      this.searchTerm = searchTerm;
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-rounded-none gl-border-b-1 gl-border-b-default gl-bg-default !gl-p-0 gl-pb-2 gl-border-b-solid"
    content-classes="gl-justify-between gl-pb-3 gl-rounded-none gl-pl-3"
    @remove="$emit('remove')"
  >
    <template #content>
      <gl-collapsible-listbox
        block
        fluid-width
        searchable
        class="gl-w-48"
        :items="items"
        :header-text="$options.i18n.defaultText"
        :selected="selected"
        :toggle-text="toggleText"
        @search="debouncedSearch"
        @select="selectVariable"
      />
    </template>
  </section-layout>
</template>
