<script>
import {
  GlBadge,
  GlLink,
  GlButton,
  GlModal,
  GlTooltip,
  GlFormInput,
  GlFormTextarea,
  GlFormGroup,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { cloneDeep, omit } from 'lodash';
import { s__, __, sprintf } from '~/locale';
import {
  requirementDefaultValidationState,
  maxControlsNumber,
  requirementsDocsUrl,
  requirementEvents,
} from '../constants';

export default {
  name: 'RequirementModal',
  components: {
    GlModal,
    GlFormInput,
    GlFormTextarea,
    GlFormGroup,
    GlBadge,
    GlLink,
    GlButton,
    GlTooltip,
    GlCollapsibleListbox,
  },
  props: {
    requirement: {
      type: Object,
      required: true,
    },
    gitlabStandardControls: {
      type: Array,
      required: true,
    },
    isNewFramework: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      requirementData: null,
      validation: { ...requirementDefaultValidationState },
      controls: [],
      searchQuery: '',
    };
  },
  computed: {
    isEdit() {
      return Boolean(this.requirementData?.id || this.requirementData?.index !== null);
    },
    title() {
      return this.isEdit ? this.$options.i18n.editText : this.$options.i18n.createTitle;
    },
    disabledAddControlBtnText() {
      return sprintf(
        s__('ComplianceFrameworks|You can create a maximum of %{maxControlsNumber} controls'),
        { maxControlsNumber },
      );
    },
    controlItems() {
      return this.gitlabStandardControls
        .filter((control) => !this.controls.some((c) => c?.name === control.id))
        .filter((control) => control.name.toLowerCase().includes(this.searchQuery.toLowerCase()))
        .map(({ id, name }) => ({ value: id, text: name }));
    },
    isFormValid() {
      return Object.values(this.validation).every(Boolean);
    },
    modalButtonProps() {
      const { createButtonText, editText, existingFrameworkButtonText } = this.$options.i18n;

      let text = existingFrameworkButtonText;

      if (this.isNewFramework) {
        text = this.isEdit ? editText : createButtonText;
      }

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

    canAddControl() {
      return this.controls.length < maxControlsNumber;
    },
    controlsLength() {
      return this.controls.filter((control) => control?.name).length;
    },
  },
  watch: {
    requirement: {
      immediate: true,
      handler(newRequirement) {
        this.requirementData = cloneDeep(newRequirement);
        this.initializeControls();
        this.validation = { ...requirementDefaultValidationState };
      },
    },
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
    initializeControls() {
      const requirementControls = this.requirementData?.complianceRequirementsControls?.nodes || [];
      if (requirementControls.length) {
        this.controls = requirementControls.map((control) => {
          const standardControl = this.gitlabStandardControls.find(
            (ctrl) => ctrl.id === control.name,
          );
          return {
            id: control.id,
            name: standardControl?.id,
            controlType: control.controlType,
            expression: control.expression,
            displayName: standardControl?.name,
          };
        });
      } else {
        this.controls = [null];
      }
    },
    validateField(key) {
      this.validation[key] = Boolean(this.requirementData[key]);
    },
    validateForm() {
      Object.keys(this.validation).forEach(this.validateField);
    },
    removeTypename(obj) {
      const { __typename, ...rest } = obj;
      return rest;
    },
    handleSubmit(event) {
      this.validateForm();
      if (this.isFormValid) {
        const stagedControls = this.controls
          .map((control) => {
            if (!control) return null;

            if (control.expression) {
              const expressionWithoutTypename = omit(control.expression, '__typename');
              const expression = Object.keys(expressionWithoutTypename).length
                ? JSON.stringify(expressionWithoutTypename)
                : null;
              return {
                ...control,
                expression,
              };
            }

            return {
              ...control,
              expression: null,
            };
          })
          .filter(Boolean);

        const { index, ...requirement } = this.requirementData;
        requirement.stagedControls = stagedControls;
        const eventName = this.isEdit ? requirementEvents.update : requirementEvents.create;

        this.$emit(eventName, {
          requirement,
          index,
        });
      } else {
        event.preventDefault();
      }
    },
    getToggleText(control) {
      return control?.controlType === 'external'
        ? this.$options.i18n.externalControl
        : control?.displayName || this.$options.i18n.toggleText;
    },
    getSelected(control) {
      return control?.id || null;
    },
    addControl() {
      if (this.canAddControl) {
        this.controls.push(null);
      }
    },
    removeControl(index) {
      this.controls.splice(index, 1);
    },
    onControlSelect(index, selectedId) {
      if (!selectedId) {
        this.controls.splice(index, 1, null);
        return;
      }

      const selectedControl = this.gitlabStandardControls.find((ctrl) => ctrl.id === selectedId);
      if (selectedControl) {
        this.controls.splice(index, 1, {
          id: this.controls[index]?.id,
          name: selectedControl.id,
          expression: selectedControl.expression,
          displayName: selectedControl.name,
          controlType: 'internal',
        });
      }
    },
    disabled(control) {
      return control?.controlType === 'external';
    },
  },
  requirementsDocsUrl,
  i18n: {
    createTitle: s__('ComplianceFrameworks|Create new requirement'),
    editText: s__('ComplianceFrameworks|Edit requirement'),
    createButtonText: s__('ComplianceFrameworks|Create requirement'),
    existingFrameworkButtonText: s__('ComplianceFrameworks|Save changes to the framework'),
    nameInput: s__('ComplianceFrameworks|Name'),
    descriptionInput: s__('ComplianceFrameworks|Description'),
    controlsTitle: s__('ComplianceFrameworks|Controls (optional)'),
    controlsText: s__(
      'ComplianceFrameworks|Controls are pre-defined rules that are configured for GitLab resources.',
    ),
    learnMore: __('Learn more.'),
    nameInputInvalid: s__('ComplianceFrameworks|Name is required'),
    descriptionInputInvalid: s__('ComplianceFrameworks|Description is required'),
    addControl: s__('ComplianceFrameworks|Add a GitLab control'),
    toggleText: s__('ComplianceFrameworks|Choose a standard control'),
    externalControl: s__('ComplianceFrameworks|External control'),
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
    <b>{{ $options.i18n.controlsTitle }}</b>
    <gl-badge>{{ controlsLength }}</gl-badge>
    <p>
      {{ $options.i18n.controlsText }}
      <gl-link :href="$options.requirementsDocsUrl" target="_blank">{{
        $options.i18n.learnMore
      }}</gl-link>
    </p>

    <div
      v-for="(control, index) in controls"
      :key="index"
      class="gl-mb-3 gl-flex gl-justify-between gl-rounded-base gl-bg-gray-10 gl-p-3"
    >
      <gl-collapsible-listbox
        placement="bottom"
        positioning-strategy="fixed"
        boundary="viewport"
        :data-testid="`control-select-${index}`"
        :selected="getSelected(control)"
        searchable
        :toggle-text="getToggleText(control)"
        :items="controlItems"
        :disabled="disabled(control)"
        @select="onControlSelect(index, $event)"
        @search="searchQuery = $event"
      />

      <gl-button
        :aria-label="$options.i18n.removeControl"
        category="tertiary"
        icon="remove"
        @click="removeControl(index)"
      />
    </div>

    <gl-tooltip
      v-if="!canAddControl"
      placement="right"
      :target="() => $refs.addControlBtn"
      :title="disabledAddControlBtnText"
    />
    <div ref="addControlBtn" class="gl-inline-block">
      <gl-button
        size="small"
        category="secondary"
        variant="confirm"
        class="gl-mt-3 gl-block"
        data-testid="add-control-button"
        :disabled="!canAddControl"
        @click="addControl"
      >
        {{ $options.i18n.addControl }}
      </gl-button>
    </div>
  </gl-modal>
</template>
