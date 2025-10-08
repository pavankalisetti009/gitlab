<script>
import {
  GlBadge,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
  GlTableLite,
  GlLabel,
  GlButton,
  GlTooltipDirective,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import {
  defaultCategory,
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
} from './constants';

export default {
  components: {
    GlBadge,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlTableLite,
    GlLabel,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    CrudComponent,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedCategory: {
      type: Object,
      required: false,
      default: () => defaultCategory,
    },
    unsavedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      category: {
        name: '',
        description: '',
      },
      formErrors: {
        name: null,
        multipleSelection: null,
      },
    };
  },
  computed: {
    isNew() {
      return !this.category?.id;
    },
    isLocked() {
      return this.category?.editableState === CATEGORY_LOCKED;
    },
    isLimited() {
      return this.category?.editableState === CATEGORY_PARTIALLY_EDITABLE;
    },
    isCategoryEditable() {
      return this.category?.editableState === CATEGORY_EDITABLE || this.isNew;
    },
    areAttributesEditable() {
      return !this.isLocked || this.isNew;
    },
    attributes() {
      return [...(this.category?.securityAttributes || []), ...this.unsavedAttributes];
    },
  },
  watch: {
    selectedCategory(newCategory) {
      this.category = newCategory;
      this.formErrors.name = null;
      this.formErrors.multipleSelection = null;
    },
  },
  mounted() {
    this.category = this.selectedCategory || defaultCategory;
  },
  methods: {
    isFormValid() {
      this.formErrors.name =
        this.category.name.trim() === '' ? s__('SecurityAttributes|Name is required') : null;
      this.formErrors.multipleSelection =
        this.category.multipleSelection === null
          ? s__('SecurityAttributes|Selection type is required')
          : null;
      return !this.formErrors.name && !this.formErrors.multipleSelection;
    },
    handleSubmit() {
      if (!this.isFormValid()) return;
      this.$emit('saveCategory', this.category);
    },
  },
  attributesTableFields: [
    {
      key: 'name',
      label: s__('SecurityAttributes|Attribute'),
      // eslint-disable-next-line @gitlab/require-i18n-strings
      tdClass: '!gl-border-b-0 gl-md-w-1/5',
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: '!gl-border-t-0 gl-md-w-1/5',
    },
    {
      key: 'description',
      label: __('Description'),
      tdClass: '!gl-border-b-0 gl-md-w-[55%]',
      thClass: '!gl-border-t-0 gl-md-w-[55%]',
    },
    {
      key: 'usedBy',
      label: __('Used by'),
      tdClass: '!gl-border-b-0 gl-md-w-[15%]',
      thClass: '!gl-border-t-0 gl-md-w-[15%]',
    },
    {
      key: 'actions',
      label: '',
      tdClass: '!gl-border-b-0 gl-md-w-[10%] gl-text-right',
      thClass: '!gl-border-t-0 gl-md-w-[10%]',
    },
  ],
  editItem: {
    text: __('Edit'),
  },
  deleteItem: {
    text: __('Delete'),
  },
  singleSelection: s__('SecurityAttributes|Single selection'),
  multipleSelection: s__('SecurityAttributes|Multiple selection'),
};
</script>
<template>
  <div>
    <div class="gl-p-6">
      <div class="gl-float-right">
        <gl-badge
          v-if="isLocked"
          v-gl-tooltip="
            s__(
              'SecurityAttributes|You cannot delete or edit this category. You cannot modify the attributes.',
            )
          "
          icon="lock"
        >
          {{ s__('SecurityAttributes|Category locked') }}
        </gl-badge>
        <gl-badge
          v-else-if="isLimited"
          v-gl-tooltip="
            s__(
              'SecurityAttributes|You cannot delete this category, but you can edit the attributes.',
            )
          "
          icon="pencil"
        >
          {{ s__('SecurityAttributes|Limited edits allowed') }}
        </gl-badge>
        <gl-disclosure-dropdown v-else-if="!isNew" category="tertiary" icon="ellipsis_v" no-caret>
          <gl-disclosure-dropdown-item
            :item="$options.deleteItem"
            data-testid="delete-category-item"
            @action="$emit('deleteCategory', category)"
          />
        </gl-disclosure-dropdown>
      </div>
      <h3 class="gl-heading-3" data-testid="category-form-title">
        {{ isNew ? s__('SecurityAttributes|Category details') : category.name }}
      </h3>
      <p>{{ s__('SecurityAttributes|View category settings and associated attributes.') }}</p>
      <gl-form @submit.prevent>
        <gl-form-group
          :label="s__('SecurityAttributes|Name')"
          :state="formErrors.name === null"
          :invalid-feedback="formErrors.name"
          data-testid="category-name-group"
        >
          <gl-form-input
            v-if="isCategoryEditable"
            v-model="category.name"
            :state="formErrors.name === null"
            data-testid="category-name-input"
          />
          <span v-else>{{ category.name }}</span>
        </gl-form-group>
        <gl-form-group :label="__('Description')">
          <gl-form-textarea v-if="isCategoryEditable" v-model="category.description" />
          <span v-else>{{ category.description }}</span>
        </gl-form-group>
        <gl-form-group
          :state="formErrors.multipleSelection === null"
          :invalid-feedback="formErrors.multipleSelection"
          data-testid="selection-type-group"
        >
          <template #label>
            {{ s__('SecurityAttributes|Selection type') }}
            <gl-icon
              v-gl-tooltip="
                s__(
                  'SecurityAttributes|You cannot change the selection type after the category is created. To use a different selection type, create a new category.',
                )
              "
              variant="info"
              name="information-o"
            />
          </template>
          <gl-form-radio-group
            v-if="isNew"
            v-model="category.multipleSelection"
            data-testid="selection-type-input"
          >
            <gl-form-radio :value="false" class="gl-z-0">
              {{ $options.singleSelection }}
            </gl-form-radio>
            <gl-form-radio :value="true" class="gl-z-0">
              {{ $options.multipleSelection }}
            </gl-form-radio>
          </gl-form-radio-group>
          <span v-else>
            {{ category.multipleSelection ? $options.multipleSelection : $options.singleSelection }}
          </span>
        </gl-form-group>
        <gl-button
          v-if="areAttributesEditable"
          category="secondary"
          variant="confirm"
          size="small"
          class="gl-float-right"
          data-testid="add-attribute-button"
          @click="$emit('addAttribute')"
        >
          {{ s__('SecurityAttributes|Create attribute') }}
        </gl-button>
        <gl-form-group
          :description="s__('SecurityAttributes|View the attributes available in this category')"
          :state="formErrors.attributes === null"
          :invalid-feedback="formErrors.attributes"
        >
          <template #label>
            {{ s__('SecurityAttributes|Attributes') }}
            <span class="gl-font-normal gl-text-subtle">
              <gl-icon name="label" />
              {{ attributes.length }}
            </span>
          </template>
        </gl-form-group>
        <crud-component header-class="gl-hidden">
          <gl-table-lite
            :items="attributes"
            :fields="$options.attributesTableFields"
            stacked="md"
            class="gl-mb-0"
          >
            <template #cell(name)="{ item: { name, color } }">
              <gl-label :background-color="color" :title="name" />
            </template>
            <template #cell(usedBy)="{ item: { projectCount } }">
              <gl-link v-if="!isNaN(projectCount)">
                {{ n__('%d project', '%d projects', projectCount) }}
              </gl-link>
            </template>
            <template v-if="areAttributesEditable" #cell(actions)="{ item }">
              <gl-disclosure-dropdown category="tertiary" icon="ellipsis_v" no-caret>
                <gl-disclosure-dropdown-item
                  :item="$options.editItem"
                  data-testid="edit-attribute-item"
                  @action="$emit('editAttribute', item)"
                />
                <gl-disclosure-dropdown-item
                  :item="$options.deleteItem"
                  data-testid="delete-attribute-item"
                  @action="$emit('deleteAttribute', item)"
                />
              </gl-disclosure-dropdown>
            </template>
          </gl-table-lite>
        </crud-component>
      </gl-form>
    </div>
    <div v-if="!isLocked" class="gl-border-t gl-sticky gl-bottom-0 gl-w-full gl-bg-default gl-p-6">
      <gl-button
        category="primary"
        variant="confirm"
        data-testid="save-button"
        @click="handleSubmit"
      >
        {{ s__('SecurityAttributes|Save changes') }}
      </gl-button>
    </div>
  </div>
</template>
