<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import getSecurityAttributesByCategoryQuery from '../../graphql/client/security_attributes_by_category.query.graphql';

export default {
  components: {
    GlCollapsibleListbox,
  },
  inject: ['groupFullPath'],
  props: {
    category: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    projectAttributes: {
      type: Array,
      required: true,
    },
    selectedAttributesInCategory: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      group: {
        securityAttributes: { nodes: [] },
      },
      search: '',
      selectedAttribute: null,
      selectedAttributes: [],
    };
  },
  apollo: {
    group: {
      query: getSecurityAttributesByCategoryQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
          categoryId: this.category.id,
        };
      },
    },
  },
  computed: {
    items() {
      const items = this.group.securityAttributes.nodes.map((attribute) => ({
        value: attribute.id,
        text: attribute.name,
        ...attribute,
      }));
      if (this.search) {
        return items.filter((item) => item.text.toLowerCase().includes(this.search.toLowerCase()));
      }
      return items;
    },
    isBlank() {
      return !this.selectedAttribute && !this.selectedAttributes.length;
    },
    knownAttributes() {
      return [...this.projectAttributes, ...this.group.securityAttributes.nodes];
    },
    boundValue: {
      get() {
        return this.category.multipleSelection ? this.selectedAttributes : this.selectedAttribute;
      },
      set(value) {
        if (this.category.multipleSelection) {
          this.selectedAttributes = value;
        } else {
          this.selectedAttribute = value;
        }
      },
    },
    toggleText() {
      if (this.isBlank) return __('None');
      return this.category.multipleSelection
        ? this.toggleTextForMultipleSelection
        : this.toggleTextForSingleSelection;
    },
    toggleTextForMultipleSelection() {
      const firstTwoAttributes = this.selectedAttributes.slice(0, 2);
      const names = firstTwoAttributes.map(
        (attributeId) =>
          this.knownAttributes.find((attribute) => attribute.id === attributeId)?.name || '',
      );
      if (this.selectedAttributes.length > 2) {
        names.push(`+${this.selectedAttributes.length - 2} more`);
      }
      return names.join(', ');
    },
    toggleTextForSingleSelection() {
      const name = this.knownAttributes.find(
        (attribute) => attribute.id === this.selectedAttribute,
      )?.name;
      return name;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.handleSearch, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  mounted() {
    this.selectedAttribute = this.selectedAttributesInCategory[0]?.id || null;
    this.selectedAttributes =
      this.selectedAttributesInCategory.map((attribute) => attribute.id) || [];
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    handleSearch(search) {
      this.search = search.trim();
    },
    onSearch(term) {
      const handler = this.category.multipleSelection ? this.debouncedSearch : this.handleSearch;
      handler(term);
    },
    handleSelect(selected) {
      if (this.category.multipleSelection) {
        this.selectedAttributes = selected;
        this.selectedAttribute = null;
      } else {
        this.selectedAttribute = selected;
        this.selectedAttributes = [];
      }
      this.$emit('change', {
        categoryId: this.category.id,
        selectedAttributes: this.category.multipleSelection ? selected : [selected],
      });
    },
    handleReset() {
      this.selectedAttributes = [];
      this.selectedAttribute = null;
      this.$emit('change', {
        categoryId: this.category.id,
        selectedAttributes: [],
      });
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    v-model="boundValue"
    :multiple="category.multipleSelection"
    :toggle-text="toggleText"
    :toggle-class="{ '!gl-text-subtle': isBlank }"
    :header-text="s__('SecurityAttributes|Select security attributes')"
    :items="items"
    :reset-button-label="__('Clear')"
    :searchable="true"
    block
    @search="onSearch"
    @select="handleSelect"
    @reset="handleReset"
  >
    <template #list-item="{ item }">
      <div class="gl-flex gl-items-center gl-gap-3 gl-break-anywhere">
        <span
          :style="{ background: item.color }"
          class="gl-border gl-h-3 gl-w-5 gl-shrink-0 gl-rounded-base gl-border-white"
        ></span>
        {{ item.text }}
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
