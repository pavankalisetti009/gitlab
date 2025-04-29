<script>
import { debounce } from 'lodash';
import { GlDropdownDivider, GlDropdownItem, GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';

export default {
  i18n: {
    createKeyLabel: s__('SecurityOrchestration|Create custom variable'),
    defaultText: s__('SecurityOrchestration|Select a variable'),
    inputPlaceholder: s__('SecurityOrchestration|Type in custom variable'),
  },
  name: 'VariablesSelector',
  components: {
    GlCollapsibleListbox,
    GlDropdownDivider,
    GlDropdownItem,
    GlFormInput,
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
    hasValidationError: {
      type: Boolean,
      required: false,
      default: false,
    },
    errorMessage: {
      type: String,
      required: false,
      default: s__('SecurityOrchestration|Please remove duplicates.'),
    },
  },
  data() {
    return {
      isCustomVariable: Boolean(this.selected) && !FLAT_LIST_OPTIONS.includes(this.selected),
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
    this.debouncedInput = debounce(this.selectVariable, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
    this.debouncedInput.cancel();
  },
  methods: {
    createCustomVariable() {
      this.isCustomVariable = true;
    },
    selectVariable(variable) {
      this.$emit('select', variable);
    },
    setSearchTerm(searchTerm) {
      this.searchTerm = searchTerm;
    },
    removeVariable() {
      this.isCustomVariable = false;
      this.$emit('remove');
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-rounded-none gl-border-b-1 gl-border-b-default gl-bg-default !gl-p-0 gl-pb-2 gl-border-b-solid"
    content-classes="gl-justify-between gl-pb-3 gl-rounded-none gl-pl-3"
    @remove="removeVariable"
  >
    <template #content>
      <gl-collapsible-listbox
        v-if="!isCustomVariable"
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
      >
        <template #footer>
          <gl-dropdown-divider />
          <gl-dropdown-item class="gl-list-none" @click="createCustomVariable">
            {{ $options.i18n.createKeyLabel }}
          </gl-dropdown-item>
        </template>
      </gl-collapsible-listbox>

      <div v-else class="gl-w-full">
        <gl-form-input
          data-testid="custom-variable-input"
          class="gl-w-48"
          :state="!hasValidationError"
          :value="selected"
          :placeholder="$options.i18n.inputPlaceholder"
          @input="debouncedInput"
        />

        <p v-if="hasValidationError" data-testid="error-message" class="gl-my-2 gl-text-danger">
          {{ errorMessage }}
        </p>
      </div>
    </template>
  </section-layout>
</template>
