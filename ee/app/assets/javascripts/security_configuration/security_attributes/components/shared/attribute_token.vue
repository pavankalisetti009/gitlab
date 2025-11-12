<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { OPERATORS_TO_GROUP } from '~/vue_shared/components/filtered_search_bar/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';

export default {
  name: 'AttributeToken',
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedValues: [],
    };
  },
  computed: {
    tokenValue() {
      return {
        data: this.active ? [] : this.value.data,
        operator: this.value.operator,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.config.attributeOptions,
        selected: this.selectedValues,
        maxOptionsShown: 2,
      });
    },
    isMultiSelect() {
      return this.config.multiSelect && OPERATORS_TO_GROUP.includes(this.value.operator);
    },
  },
  methods: {
    resetSelected() {
      this.selectedValues = [];
    },
    toggleSelected(selectedValue) {
      if (!this.isMultiSelect) {
        this.selectedValues = [selectedValue];
        this.$emit('complete', { ...this.value, data: selectedValue });
        return;
      }
      if (this.selectedValues.includes(selectedValue)) {
        this.selectedValues = this.selectedValues.filter((s) => s !== selectedValue);
        return;
      }
      this.selectedValues.push(selectedValue);
    },
    isSelected(value) {
      return this.selectedValues.includes(value);
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    v-bind="{ ...$props, ...$attrs }"
    :config="config"
    :multi-select-values="selectedValues"
    :value="tokenValue"
    v-on="$listeners"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span>{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="attribute in config.attributeOptions"
        :key="attribute.id"
        :value="attribute.id"
      >
        <div class="gl-flex gl-items-center">
          <gl-icon
            v-if="isMultiSelect"
            name="check"
            class="gl-mr-3 gl-shrink-0"
            :class="{
              'gl-invisible': !selectedValues.includes(attribute.id),
            }"
            variant="subtle"
          />
          {{ attribute.name }}
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
