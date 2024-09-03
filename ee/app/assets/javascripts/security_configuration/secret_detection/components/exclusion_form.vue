<script>
import {
  GlForm,
  GlFormTextarea,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormCheckbox,
  GlAlert,
  GlButton,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, __, n__ } from '~/locale';
import {
  EXCLUSION_TYPES,
  STATUS_TYPES,
  ExclusionType,
  StatusType,
  ExclusionScannerEnum,
} from '../constants';
import projectSecurityExclusionCreateMutation from '../graphql/project_security_exclusion_create.mutation.graphql';

export default {
  components: {
    GlForm,
    GlFormTextarea,
    GlFormGroup,
    GlFormRadioGroup,
    GlFormCheckbox,
    GlAlert,
    GlButton,
  },
  inject: ['projectFullPath'],
  props: {
    exclusion: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      typeOptions: EXCLUSION_TYPES,
      statusOptions: STATUS_TYPES,
      form: {
        type: this.exclusion.type || ExclusionType.PATH,
        value: this.exclusion.value || '',
        description: this.exclusion.description || '',
        secretPushProtection: this.exclusion.secretPushProtection ?? true,
        status: this.exclusion.status || StatusType.ENABLE,
      },
      isLoading: false,
      showAlert: false,
      errors: [],
    };
  },
  computed: {
    errorTitle() {
      return n__(
        'SecurityExclusions|The following error occured while saving the exclusion:',
        'SecurityExclusions|The following errors occured while saving the exclusion:',
        this.errors.length,
      );
    },
    selectedType() {
      return this.typeOptions.find((option) => option.value === this.form.type);
    },
    mutationVariables() {
      return {
        projectPath: this.projectFullPath,
        type: this.form.type,
        value: this.form.value,
        description: this.form.description,
        scanner: ExclusionScannerEnum.SECRET_PUSH_PROTECTION,
        active: this.form.status === StatusType.ENABLE,
      };
    },
  },
  methods: {
    async saveExclusions() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: projectSecurityExclusionCreateMutation,
          variables: {
            input: this.mutationVariables,
          },
        });

        const { errors } = data.projectSecurityExclusionCreate;

        if (errors.length > 0) {
          this.showErrors(errors);
          return;
        }
        this.$toast.show(s__('SecurityExclusions|Exclusion has been created successfully'));
        this.$emit('saved');
      } catch (error) {
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
    submit() {
      this.isLoading = true;
      this.hideErrors();
      this.saveExclusions();
    },
    cancel() {
      this.$emit('cancel');
    },
    showErrors(errors = []) {
      this.errors = errors;
      this.showAlert = true;
    },
    hideErrors() {
      this.errors = [];
      this.showAlert = false;
    },
  },
  i18n: {
    typeLabel: s__('SecurityExclusions|Type'),
    typeDescription: s__('SecurityExclusions|Select which type of content to exclude'),
    contentLabel: s__('SecurityExclusions|Value'),
    descriptionLabel: s__('SecurityExclusions|Description'),
    descriptionDescription: s__(
      'SecurityExclusions|Provide context for why the content is being excluded.',
    ),
    descriptionPlaceholder: s__('SecurityExclusions|ex: This secret is used for testing'),
    enforcementLabel: s__('SecurityExclusions|Enforcement'),
    enforcementDescription: s__(
      'SecurityExclusions|Select the secret detection methods this exclusion should apply to.',
    ),
    secretPushProtection: s__('SecurityExclusions|Secret push protection'),
    statusLabel: s__('SecurityExclusions|Status'),
    cancelButton: __('Cancel'),
    saveButton: s__('SecurityExclusions|Add Exclusion'),
    unknownError: __('Something went wrong. Please try again.'),
  },
  projectSecurityExclusionCreateMutation,
};
</script>

<template>
  <gl-form @submit.prevent="submit">
    <gl-alert
      v-if="showAlert"
      variant="danger"
      :title="errorTitle"
      class="gl-mb-5"
      @dismiss="hideErrors"
    >
      <ul v-if="errors.length" class="gl-mb-0 gl-mt-3">
        <li v-for="error in errors" :key="error" v-text="error"></li>
      </ul>
    </gl-alert>
    <gl-form-group
      :label="$options.i18n.typeLabel"
      :label-description="$options.i18n.typeDescription"
    >
      <gl-form-radio-group v-model="form.type" :options="typeOptions" stacked>
        <template #help="{ option }">
          {{ option.description }}
        </template>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.contentLabel"
      :label-description="selectedType.contentDescription"
    >
      <gl-form-textarea
        v-model="form.value"
        :placeholder="selectedType.contentPlaceholder"
        rows="5"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionLabel"
      :label-description="$options.i18n.descriptionDescription"
    >
      <gl-form-textarea
        v-model="form.description"
        :placeholder="$options.i18n.descriptionPlaceholder"
        rows="3"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.enforcementLabel"
      :label-description="$options.i18n.enforcementDescription"
    >
      <gl-form-checkbox v-model="form.secretPushProtection">
        {{ $options.i18n.secretPushProtection }}
      </gl-form-checkbox>
    </gl-form-group>

    <gl-form-group :label="$options.i18n.statusLabel">
      <gl-form-radio-group v-model="form.status" :options="statusOptions" />
    </gl-form-group>

    <div>
      <gl-button
        :loading="isLoading"
        type="submit"
        variant="confirm"
        data-testid="form-submit-button"
        @click.prevent="submit"
        >{{ $options.i18n.saveButton }}</gl-button
      >
      <gl-button
        class="gl-ml-3"
        variant="default"
        data-testid="form-cancel-button"
        @click="cancel"
        >{{ $options.i18n.cancelButton }}</gl-button
      >
    </div>
  </gl-form>
</template>
