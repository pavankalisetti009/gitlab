<script>
import { GlModal, GlFormInput, GlFormTextarea, GlFormGroup } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { requirementDefaultValidationState } from '../constants';

export default {
  name: 'RequirementModal',
  components: {
    GlModal,
    GlFormInput,
    GlFormTextarea,
    GlFormGroup,
  },
  props: {
    requirement: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      requirementData: null,
      validation: {
        ...requirementDefaultValidationState,
      },
    };
  },
  computed: {
    title() {
      return this.requirementData?.id
        ? this.$options.i18n.editTitle
        : this.$options.i18n.createTitle;
    },
    isFormValid() {
      return Object.values(this.validation).every((field) => field === true);
    },
    modalButtonProps() {
      const text = this.requirementData?.id
        ? this.$options.i18n.editButtonText
        : this.$options.i18n.createButtonText;
      return {
        primary: {
          text,
          attributes: { category: 'primary', variant: 'confirm' },
        },
        cancel: {
          text: __('Cancel'),
        },
      };
    },
  },
  watch: {
    requirement: {
      immediate: true,
      handler(newRequirement) {
        this.requirementData = { ...newRequirement };
        this.validation = {
          ...requirementDefaultValidationState,
        };
      },
    },
  },
  methods: {
    show() {
      this.requirementData = { ...this.requirement };
      this.validation = {
        name: null,
        description: null,
      };
      this.$nextTick(() => {
        this.$refs.modal.show();
      });
    },
    validateField(key) {
      if (!this.requirementData[key]) {
        this.validation[key] = false;
      } else {
        this.validation[key] = true;
      }
    },
    validateForm() {
      Object.keys(this.validation).forEach((key) => this.validateField(key));
    },
    handleSubmit(event) {
      this.validateForm();
      if (this.isFormValid) {
        this.$emit('save', this.requirementData);
      } else {
        event.preventDefault();
      }
    },
  },
  i18n: {
    createTitle: s__('ComplianceFrameworks|Create new requirement'),
    editTitle: s__('ComplianceFrameworks|Edit requirement'),
    createButtonText: s__('ComplianceFrameworks|Create requirement'),
    editButtonText: s__('ComplianceFrameworks|Edit requirement'),
    nameInput: s__('ComplianceFrameworks|Name'),
    descriptionInput: s__('ComplianceFrameworks|Description'),
    controlsTitle: s__('ComplianceFrameworks|Controls'),
    controlsText: s__(
      'ComplianceFrameworks|Controls are pre-defined rules that are configured for GitLab resources.',
    ),
    learnMore: __('Learn more.'),
    nameInputInvalid: s__('ComplianceFrameworks|Name is required'),
    descriptionInputInvalid: s__('ComplianceFrameworks|Description is required'),
    addNewControl: s__('ComplianceFrameworks|Add a new control'),
    toggleText: s__('ComplianceFrameworks|Choose a standard control'),
    removeControl: s__('ComplianceFrameworks|Remove control'),
  },
};
</script>

<template>
  <gl-modal
    v-if="requirementData"
    ref="modal"
    :title="title"
    modal-id="requirement-modal"
    :action-primary="modalButtonProps.primary"
    :action-cancel="modalButtonProps.cancel"
    @primary="handleSubmit"
  >
    <gl-form-group
      :label="$options.i18n.nameInput"
      label-for="name-input"
      :invalid-feedback="$options.i18n.nameInputInvalid"
      :state="validation.name"
      data-testid="name-input-group"
    >
      <gl-form-input
        id="name-input"
        v-model="requirementData.name"
        name="name"
        data-testid="name-input"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionInput"
      :invalid-feedback="$options.i18n.descriptionInputInvalid"
      :state="validation.description"
      data-testid="description-input-group"
    >
      <gl-form-textarea
        id="description-input"
        v-model="requirementData.description"
        name="description"
        data-testid="description-input"
        :no-resize="false"
        :rows="5"
      />
    </gl-form-group>
  </gl-modal>
</template>
