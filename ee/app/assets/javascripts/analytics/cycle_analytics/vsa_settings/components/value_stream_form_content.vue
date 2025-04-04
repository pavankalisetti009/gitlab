<script>
import { GlAlert, GlButton, GlForm, GlFormInput, GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { cloneDeep, uniqueId } from 'lodash';
import { filterStagesByHiddenStatus } from '~/analytics/cycle_analytics/utils';
import { swapArrayItems } from '~/lib/utils/array_utility';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { visitUrlWithAlerts, mergeUrlParams } from '~/lib/utils/url_utility';
import { getLabelEventsIdentifiers } from 'ee/analytics/cycle_analytics/utils';
import { createValueStream, updateValueStream } from 'ee/api/analytics_api';
import {
  validateValueStreamName,
  cleanStageName,
  validateStage,
  formatStageDataForSubmission,
  hasDirtyStage,
  prepareStageErrors,
} from '../utils';
import {
  STAGE_SORT_DIRECTION,
  i18n,
  defaultCustomStageFields,
  PRESET_OPTIONS,
  PRESET_OPTIONS_DEFAULT,
  VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID,
} from '../constants';
import ValueStreamFormContentActions from './value_stream_form_content_actions.vue';
import CustomStageFields from './custom_stage_fields.vue';
import DefaultStageFields from './default_stage_fields.vue';

const initializeStageErrors = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) =>
  selectedPreset === PRESET_OPTIONS_DEFAULT ? defaultStageConfig.map(() => ({})) : [{}];

const initializeStages = (defaultStageConfig, selectedPreset = PRESET_OPTIONS_DEFAULT) => {
  const stages =
    selectedPreset === PRESET_OPTIONS_DEFAULT
      ? defaultStageConfig
      : [{ ...defaultCustomStageFields }];
  return stages.map((stage) => ({ ...stage, transitionKey: uniqueId('stage-') }));
};

const initializeEditingStages = (stages = []) =>
  filterStagesByHiddenStatus(cloneDeep(stages), false).map((stage) => ({
    ...stage,
    transitionKey: uniqueId(`stage-${stage.name}-`),
  }));

export default {
  name: 'ValueStreamFormContent',
  components: {
    CrudComponent,
    GlAlert,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormGroup,
    GlFormRadioGroup,
    DefaultStageFields,
    CustomStageFields,
    ValueStreamFormContentActions,
  },
  mixins: [Tracking.mixin()],
  inject: ['vsaPath', 'namespaceFullPath', 'stageEvents'],
  props: {
    initialData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    defaultStageConfig: {
      type: Array,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const {
      defaultStageConfig = [],
      initialData: { name: initialName, stages: initialStages = [] },
    } = this;

    return {
      hiddenStages: filterStagesByHiddenStatus(initialStages),
      selectedPreset: PRESET_OPTIONS_DEFAULT,
      presetOptions: PRESET_OPTIONS,
      name: initialName,
      nameErrors: [],
      stageErrors: [{}],
      showSubmitError: false,
      isSubmitting: false,
      stages: this.isEditing
        ? initializeEditingStages(initialStages)
        : initializeStages(defaultStageConfig),
    };
  },
  computed: {
    isValueStreamNameValid() {
      return !this.nameErrors?.length;
    },
    invalidNameFeedback() {
      return this.nameErrors?.length ? this.nameErrors.join('\n\n') : null;
    },
    hasFormErrors() {
      return Boolean(
        this.nameErrors.length || this.stageErrors.some((obj) => Object.keys(obj).length),
      );
    },
    isDirtyEditing() {
      return (
        this.isEditing &&
        (this.hasDirtyName(this.name, this.initialData.name) ||
          hasDirtyStage(this.stages, this.initialData.stages))
      );
    },
    canRestore() {
      return this.hiddenStages.length || this.isDirtyEditing;
    },
    currentValueStreamStageNames() {
      return this.stages.map(({ name }) => cleanStageName(name));
    },
    submissionSuccessfulAlert() {
      const id = VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID;
      const message = sprintf(
        this.isEditing
          ? this.$options.i18n.SETTINGS_FORM_UPDATED
          : this.$options.i18n.SETTINGS_FORM_CREATED,
        { name: this.name },
      );

      return { id, message, variant: 'success' };
    },
    submitParams() {
      const { name, stages, isEditing } = this;
      return {
        name,
        stages: formatStageDataForSubmission(stages, isEditing),
      };
    },
  },
  methods: {
    onSubmit() {
      this.showSubmitError = false;
      this.validate();
      if (this.hasFormErrors) return;

      this.isSubmitting = true;

      this.submitRequest()
        .then(({ data: { id } }) => {
          this.track('submit_form', {
            label: this.isEditing ? 'edit_value_stream' : 'create_value_stream',
          });

          const redirectPath = mergeUrlParams({ value_stream_id: id }, this.vsaPath);
          visitUrlWithAlerts(redirectPath, [this.submissionSuccessfulAlert]);
        })
        .catch(({ response: { data } }) => {
          this.isSubmitting = false;
          this.showSubmitError = true;

          const {
            payload: { errors: { name, stages = {} } = {} },
          } = data;
          this.setErrors({
            name,
            stages: prepareStageErrors(this.submitParams.stages, stages),
          });
        });
    },
    submitRequest() {
      const { isEditing, namespaceFullPath, initialData, submitParams } = this;
      return isEditing
        ? updateValueStream({
            namespacePath: namespaceFullPath,
            valueStreamId: initialData.id,
            data: submitParams,
          })
        : createValueStream(namespaceFullPath, submitParams);
    },
    stageGroupLabel(index) {
      return sprintf(this.$options.i18n.STAGE_INDEX, { index: index + 1 });
    },
    recoverStageTitle(name) {
      return sprintf(this.$options.i18n.HIDDEN_DEFAULT_STAGE, { name });
    },
    hasDirtyName(current, original) {
      return current.trim().toLowerCase() !== original.trim().toLowerCase();
    },
    validateStages() {
      return this.stages.map((stage) =>
        validateStage({
          currentStage: stage,
          allStageNames: this.currentValueStreamStageNames,
          labelEvents: getLabelEventsIdentifiers(this.stageEvents),
        }),
      );
    },
    setErrors({ name = [], stages = [{}] }) {
      const { defaultStageConfig, selectedPreset } = this;
      this.nameErrors = name;
      this.stageErrors =
        cloneDeep(stages) || initializeStageErrors(defaultStageConfig, selectedPreset);
    },
    validate() {
      const { name } = this;
      this.nameErrors = validateValueStreamName({ name });
      this.stageErrors = this.validateStages();
    },
    moveItem(arr, index, direction) {
      return direction === STAGE_SORT_DIRECTION.UP
        ? swapArrayItems(arr, index - 1, index)
        : swapArrayItems(arr, index, index + 1);
    },
    handleMove({ index, direction }) {
      const newStages = this.moveItem(this.stages, index, direction);
      const newErrors = this.moveItem(this.stageErrors, index, direction);
      this.stages = cloneDeep(newStages);
      this.stageErrors = cloneDeep(newErrors);
    },
    validateStageFields(index) {
      const copy = [...this.stageErrors];
      copy[index] = validateStage({ currentStage: this.stages[index] });
      this.stageErrors = copy;
    },
    fieldErrors(index) {
      return this.stageErrors && this.stageErrors[index] ? this.stageErrors[index] : {};
    },
    onHide(index) {
      const target = this.stages[index];
      this.stages = [...this.stages.filter((_, i) => i !== index)];
      this.hiddenStages = [...this.hiddenStages, target];
    },
    onRemove(index) {
      const newErrors = this.stageErrors.filter((_, idx) => idx !== index);
      const newStages = this.stages.filter((_, idx) => idx !== index);
      this.stages = [...newStages];
      this.stageErrors = [...newErrors];
    },
    onRestore(hiddenStageIndex) {
      const target = this.hiddenStages[hiddenStageIndex];
      this.hiddenStages = [...this.hiddenStages.filter((_, i) => i !== hiddenStageIndex)];
      this.stages = [
        ...this.stages,
        { ...target, transitionKey: uniqueId(`stage-${target.name}-`) },
      ];
    },
    lastStage() {
      const stages = this.$refs.formStages;
      return stages[stages.length - 1];
    },
    async scrollToLastStage() {
      await this.$nextTick();
      // Scroll to the new stage we have added
      this.lastStage().focus();
      this.lastStage().scrollIntoView({ behavior: 'smooth' });
    },
    addNewStage() {
      // validate previous stages only and add a new stage
      this.validate();
      this.stages = [
        ...this.stages,
        { ...defaultCustomStageFields, transitionKey: uniqueId('stage-') },
      ];
      this.stageErrors = [...this.stageErrors, {}];
    },
    onAddStage() {
      this.addNewStage();
      this.scrollToLastStage();
    },
    onFieldInput(activeStageIndex, { field, value }) {
      const updatedStage = { ...this.stages[activeStageIndex], [field]: value };
      const copy = [...this.stages];
      copy[activeStageIndex] = updatedStage;
      this.stages = copy;
    },
    resetAllFieldsToDefault() {
      this.stages = initializeStages(this.defaultStageConfig, this.selectedPreset);
      this.hiddenStages = [];
      this.stageErrors = initializeStageErrors(this.defaultStageConfig, this.selectedPreset);
    },
    handleResetDefaults() {
      if (this.isEditing) {
        const {
          initialData: { name: initialName, stages: initialStages },
        } = this;
        this.name = initialName;
        this.nameErrors = [];
        this.stages = initializeStages(initialStages);
        this.stageErrors = [{}];
      } else {
        this.resetAllFieldsToDefault();
      }
    },
    onSelectPreset() {
      if (this.selectedPreset === PRESET_OPTIONS_DEFAULT) {
        this.handleResetDefaults();
      } else {
        this.resetAllFieldsToDefault();
      }
    },
    restoreActionTestId(index) {
      return `stage-action-restore-${index}`;
    },
  },
  i18n,
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <gl-alert v-if="showSubmitError" variant="danger" @dismiss="showSubmitError = false">
      {{ $options.i18n.SUBMIT_FAILED }}
    </gl-alert>

    <gl-form>
      <crud-component
        :title="$options.i18n.STAGES"
        :description="$options.i18n.DEFAULT_STAGE_FEATURES"
        body-class="!gl-mx-0"
      >
        <template v-if="canRestore" #actions>
          <transition name="fade">
            <gl-button data-testid="vsa-reset-button" variant="link" @click="handleResetDefaults">{{
              $options.i18n.RESTORE_DEFAULTS
            }}</gl-button>
          </transition>
        </template>

        <div class="gl-px-5">
          <gl-form-group
            data-testid="create-value-stream-name"
            label-for="create-value-stream-name"
            :label="$options.i18n.FORM_FIELD_NAME_LABEL"
            :invalid-feedback="invalidNameFeedback"
            :state="isValueStreamNameValid"
          >
            <div class="gl-flex gl-justify-between">
              <gl-form-input
                id="create-value-stream-name"
                v-model.trim="name"
                name="create-value-stream-name"
                data-testid="create-value-stream-name-input"
                :placeholder="$options.i18n.FORM_FIELD_NAME_PLACEHOLDER"
                :state="isValueStreamNameValid"
                required
              />
            </div>
          </gl-form-group>
          <gl-form-radio-group
            v-if="!isEditing"
            v-model="selectedPreset"
            class="gl-mb-4"
            data-testid="vsa-preset-selector"
            :options="presetOptions"
            name="preset"
            @input="onSelectPreset"
          />
        </div>

        <div class="gl-border-t gl-pt-5" data-testid="extended-form-fields">
          <transition-group name="stage-list" tag="div">
            <div
              v-for="(stage, activeStageIndex) in stages"
              ref="formStages"
              :key="stage.id || stage.transitionKey"
              class="gl-border-b gl-mb-5 gl-px-5 gl-pb-3"
            >
              <custom-stage-fields
                v-if="stage.custom"
                :stage-label="stageGroupLabel(activeStageIndex)"
                :stage="stage"
                :index="activeStageIndex"
                :total-stages="stages.length"
                :errors="fieldErrors(activeStageIndex)"
                @move="handleMove"
                @remove="onRemove"
                @input="onFieldInput(activeStageIndex, $event)"
              />
              <default-stage-fields
                v-else
                :stage-label="stageGroupLabel(activeStageIndex)"
                :stage="stage"
                :index="activeStageIndex"
                :total-stages="stages.length"
                :errors="fieldErrors(activeStageIndex)"
                @move="handleMove"
                @hide="onHide"
                @input="validateStageFields(activeStageIndex)"
              />
            </div>
          </transition-group>
          <div v-if="hiddenStages.length" class="gl-flex gl-flex-col">
            <gl-form-group
              v-for="(stage, hiddenStageIndex) in hiddenStages"
              :key="stage.id"
              class="gl-border-b gl-flex gl-pb-3 gl-pr-6"
              label-class="gl-flex gl-gap-5 gl-float-left"
              data-testid="vsa-hidden-stage"
            >
              <template #label>
                <div class="gl-w-8">&nbsp;</div>
                <span class="gl-heading-4 gl-mb-0">{{ recoverStageTitle(stage.name) }}</span>
              </template>
              <gl-button
                variant="link"
                :data-testid="restoreActionTestId(hiddenStageIndex)"
                @click="onRestore(hiddenStageIndex)"
                >{{ $options.i18n.RESTORE_HIDDEN_STAGE }}</gl-button
              >
            </gl-form-group>
          </div>
        </div>

        <gl-button
          class="gl-ml-5"
          icon="plus"
          data-testid="add-button"
          :disabled="isSubmitting"
          @click="onAddStage"
          >{{ $options.i18n.BTN_ADD_STAGE }}</gl-button
        >
      </crud-component>

      <value-stream-form-content-actions
        class="gl-mt-6"
        :is-editing="isEditing"
        :is-loading="isSubmitting"
        @clickPrimaryAction="onSubmit"
        @clickAddStageAction="onAddStage"
      />
    </gl-form>
  </div>
</template>
