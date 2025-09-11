<script>
import { GlButton, GlDrawer, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import AttributesCategoryDropdown from './attributes_category_dropdown.vue';

export default {
  components: {
    GlButton,
    GlDrawer,
    GlIcon,
    AttributesCategoryDropdown,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  props: {
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
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
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    flattenedAttributes() {
      return Object.values(this.selectedAttributesByCategory).flat();
    },
  },
  watch: {
    open: {
      handler(newValue) {
        if (newValue === true) {
          this.selectedAttributesByCategory = {};
          this.categories.forEach((category) => {
            this.handleSelectedAttributes({
              categoryId: category.id,
              selectedAttributes: this.selectedAttributesInCategory(category).map(
                (attribute) => attribute.id,
              ),
            });
          });
        }
      },
    },
  },
  methods: {
    selectedAttributesInCategory(category) {
      return this.selectedAttributes.filter((attribute) => attribute.category.id === category.id);
    },
    handleSelectedAttributes({ categoryId, selectedAttributes }) {
      this.selectedAttributesByCategory[categoryId] = selectedAttributes;
    },
    handleSave() {
      this.$emit('save', this.flattenedAttributes);
    },
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <gl-drawer
    :open="open"
    :header-height="getDrawerHeaderHeight"
    :header-sticky="true"
    size="md"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('cancel')"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">
        {{ s__('SecurityAttributes|Edit project security attributes') }}
      </h4>
    </template>

    <div class="!gl-py-3">
      <div v-for="category in categories" :key="category.id" class="gl-py-2">
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
        <div class="gl-mb-2 gl-text-sm gl-text-subtle">{{ category.description }}</div>
        <attributes-category-dropdown
          :category="category"
          :project-attributes="selectedAttributes"
          :selected-attributes-in-category="selectedAttributesInCategory(category)"
          @change="handleSelectedAttributes"
        />
      </div>
    </div>

    <template #footer>
      <div class="gl-display-flex gl-gap-3">
        <gl-button
          category="primary"
          variant="confirm"
          data-testid="submit-btn"
          @click="handleSave"
        >
          {{ __('Save changes') }}
        </gl-button>
        <gl-button data-testid="cancel-btn" class="gl-ml-2" @click="$emit('cancel')">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
