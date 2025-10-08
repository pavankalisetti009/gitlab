<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import AttributesCategoryDropdown from './attributes_category_dropdown.vue';

export default {
  name: 'ProjectAttributesForm',
  components: {
    GlIcon,
    AttributesCategoryDropdown,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  props: {
    categories: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      selectedAttributesByCategory: {},
    };
  },
  computed: {
    filteredCategories() {
      return this.categories.filter((category) => category.securityAttributes?.length > 0);
    },
    flattenedAttributes() {
      return Object.values(this.selectedAttributesByCategory).flat();
    },
  },
  watch: {
    categories: {
      immediate: true,
      handler(newCategories) {
        this.selectedAttributesByCategory = newCategories.reduce((acc, category) => {
          acc[category.id] = this.selectedAttributes
            .filter((a) => a.securityCategory?.id === category.id)
            .map((a) => a.id);
          return acc;
        }, {});
        this.emitUpdate();
      },
    },
  },
  methods: {
    handleSelectedAttributes({ categoryId, selectedAttributes }) {
      this.selectedAttributesByCategory = {
        ...this.selectedAttributesByCategory,
        [categoryId]: selectedAttributes,
      };
      this.emitUpdate();
    },
    emitUpdate() {
      this.$emit('update', this.flattenedAttributes);
    },
    selectedAttributesInCategory(category) {
      return this.selectedAttributesByCategory[category.id] || [];
    },
  },
};
</script>

<template>
  <div class="!gl-py-3">
    <div v-for="category in filteredCategories" :key="category.id" class="gl-py-2">
      <div>
        <h5 class="gl-mb-2">
          {{ category.name }}
          <gl-icon
            v-tooltip="
              category.multipleSelection
                ? 'Multiple attributes from this category can be applied per project'
                : 'Only one attribute from this category can be applied per project'
            "
            :name="category.multipleSelection ? 'labels' : 'label'"
            variant="subtle"
          />
        </h5>
      </div>
      <div class="gl-mb-2 gl-text-sm gl-text-subtle">
        {{ category.description }}
      </div>
      <attributes-category-dropdown
        :category="category"
        :attributes="category.securityAttributes"
        :selected-attributes-in-category="selectedAttributesInCategory(category)"
        @change="handleSelectedAttributes"
      />
    </div>
  </div>
</template>
