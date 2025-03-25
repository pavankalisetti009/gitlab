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
  GlFormInputGroup,
  GlInputGroupText,
  GlTruncate,
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
    GlFormInputGroup,
    GlInputGroupText,
    GlTruncate,
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
      const sourceControls = this.requirementData?.stagedControls?.length
        ? this.requirementData.stagedControls
        : this.requirementData?.complianceRequirementsControls?.nodes || [];

      if (sourceControls.length) {
        this.controls = sourceControls.map((control) => {
          const standardControl = this.gitlabStandardControls.find(
            (ctrl) => ctrl.id === control.name,
          );

          const baseControl = {
            id: control.id,
            name: control.name,
            controlType: control.controlType,
            displayName: control.controlType === 'external' ? control.name : standardControl?.name,
          };

          if (control.controlType === 'external') {
            return {
              ...baseControl,
              externalUrl: control.externalUrl,
              secretToken: control.secretToken,
            };
          }

          return {
            ...baseControl,
            expression: control.expression,
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
            if (!control.name) return null;

            if (control.expression) {
              if (typeof control.expression === 'string') {
                return {
                  ...control,
                  expression: control.expression,
                };
              }
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
    addControl(type = 'internal') {
      if (this.canAddControl) {
        this.controls.push({
          controlType: type,
          externalUrl: '',
          secretToken: '',
          name: type === 'external' ? 'external_control' : '',
        });
      }
    },
    addExternalControl() {
      this.addControl('external');
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
    isExternalControl(control) {
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
      'ComplianceFrameworks|GitLab controls are pre-defined rules that are configured for GitLab resources. External environmental controls use the API to check the status and details of an external environment.',
    ),
    learnMore: __('Learn more.'),
    nameInputInvalid: s__('ComplianceFrameworks|Name is required'),
    descriptionInputInvalid: s__('ComplianceFrameworks|Description is required'),
    addControl: s__('ComplianceFrameworks|Add a GitLab control'),
    addExternalControl: s__('ComplianceFrameworks|Add an external control'),
    toggleText: s__('ComplianceFrameworks|Choose a standard control'),
    externalControl: s__('ComplianceFrameworks|External control'),
    removeControl: s__('ComplianceFrameworks|Remove control'),
    externalUrlLabel: s__('ComplianceFrameworks|External URL'),
    externalUrlDescription: s__('ComplianceFrameworks|URL to external system.'),
    secretLabel: s__('ComplianceFrameworks|HMAC shared secret'),
    secretDescription: s__(
      'ComplianceFrameworks|Provide a shared secret to be used when sending a request for an external check to authenticate request using HMAC.',
    ),
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
      <div class="gl-flex-grow-1 gl-mr-3 gl-w-full">
        <template v-if="isExternalControl(control)">
          <gl-form-input-group class="">
            <template #prepend>
              <gl-input-group-text>
                <gl-truncate :text="$options.i18n.externalUrlLabel" position="middle" />
              </gl-input-group-text>
            </template>
            <gl-form-input
              v-model="control.externalUrl"
              type="url"
              :data-testid="`external-url-input-${index}`"
              class="gl-w-full"
            />
          </gl-form-input-group>
          <p class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-gray-500">
            {{ $options.i18n.externalUrlDescription }}
          </p>

          <gl-form-input-group class="gl-mt-3">
            <template #prepend>
              <gl-input-group-text>
                <gl-truncate :text="$options.i18n.secretLabel" position="middle" />
              </gl-input-group-text>
            </template>
            <gl-form-input
              v-model="control.secretToken"
              type="password"
              :data-testid="`external-secret-input-${index}`"
            />
          </gl-form-input-group>
          <p class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-gray-500">
            {{ $options.i18n.secretDescription }}
          </p>
        </template>
        <gl-collapsible-listbox
          v-else
          placement="bottom"
          positioning-strategy="fixed"
          boundary="viewport"
          :data-testid="`control-select-${index}`"
          :selected="getSelected(control)"
          searchable
          :toggle-text="getToggleText(control)"
          :items="controlItems"
          @select="onControlSelect(index, $event)"
          @search="searchQuery = $event"
        />
      </div>

      <gl-button
        :aria-label="$options.i18n.removeControl"
        category="tertiary"
        icon="remove"
        class="gl-align-top"
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

    <div ref="addExternalControlBtn" class="gl-ml-3 gl-inline-block">
      <gl-button
        size="small"
        category="secondary"
        variant="confirm"
        class="gl-mt-3 gl-block"
        data-testid="add-external-control-button"
        :disabled="!canAddControl"
        @click="addExternalControl"
      >
        {{ $options.i18n.addExternalControl }}
      </gl-button>
    </div>
  </gl-modal>
</template>
