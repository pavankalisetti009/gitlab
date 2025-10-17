<script>
import {
  GlButton,
  GlDatepicker,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlModal,
  GlSprintf,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import { isEmptyValue } from '~/lib/utils/forms';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import {
  DETAILS_ROUTE_NAME,
  INDEX_ROUTE_NAME,
  SECRET_DESCRIPTION_MAX_LENGTH,
} from '../../constants';
import createSecretMutation from '../../graphql/mutations/create_secret.mutation.graphql';
import updateSecretMutation from '../../graphql/mutations/update_secret.mutation.graphql';
import SecretBranchesField from './secret_branches_field.vue';

export default {
  name: 'SecretForm',
  components: {
    CiEnvironmentsDropdown,
    GlButton,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlModal,
    GlSprintf,
    SecretBranchesField,
  },
  props: {
    areEnvironmentsLoading: {
      type: Boolean,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    fullPath: {
      type: String,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    secretData: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      isSubmitting: false,
      secret: {
        branch: '',
        description: undefined,
        environment: '',
        expiration: undefined,
        name: undefined,
        rotationIntervalDays: this.secretData?.rotationInfo?.rotationIntervalDays || null,
        secret: undefined, // shown as "value" in the UI
        ...this.secretData,
      },
      showConfirmEditModal: false,
    };
  },
  computed: {
    canSubmit() {
      return (
        this.isBranchValid &&
        this.isNameValid &&
        this.isValueValid &&
        this.isDescriptionValid &&
        this.isEnvironmentScopeValid &&
        this.isRotationValid
      );
    },
    isBranchValid() {
      return this.secret.branch.length > 0;
    },
    isDescriptionValid() {
      return (
        this.secret.description.length > 0 &&
        this.secret.description.length <= SECRET_DESCRIPTION_MAX_LENGTH
      );
    },
    isEnvironmentScopeValid() {
      return this.secret.environment.length > 0;
    },
    isNameValid() {
      return this.secret.name?.length > 0;
    },
    isValueValid() {
      if (this.isEditing) {
        return true; // value is optional when editing
      }

      return this.secret.secret.length > 0;
    },
    isRotationValid() {
      const { rotationIntervalDays } = this.secret;
      return isEmptyValue(rotationIntervalDays) || rotationIntervalDays > 6;
    },
    minExpirationDate() {
      // secrets can expire tomorrow, but not today or yesterday
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    submitButtonText() {
      return this.isEditing ? __('Save changes') : s__('SecretsManager|Add secret');
    },
    valueFieldPlaceholder() {
      if (this.isEditing) {
        return s__('SecretsManager|Enter a new value to update secret');
      }

      return s__('SecretsManager|Enter a value for the secret');
    },
  },
  methods: {
    async createSecret() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createSecretMutation,
          variables: {
            projectPath: this.fullPath,
            rotationIntervalDays: this.secret.rotationIntervalDays,
            ...this.secret,
          },
        });

        const error = data.projectSecretCreate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      } finally {
        this.isSubmitting = false;
      }
    },
    async editSecret() {
      this.hideModal();
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateSecretMutation,
          variables: {
            projectPath: this.fullPath,
            rotationIntervalDays: this.secret.rotationIntervalDays,
            ...this.secret,
          },
        });

        const error = data.projectSecretUpdate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.showUpdateToastMessage();
        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      } finally {
        this.isSubmitting = false;
      }
    },
    hideModal() {
      this.showConfirmEditModal = false;
    },
    setBranch(branch) {
      this.secret.branch = branch;
    },
    setEnvironment(environment) {
      this.secret.environment = environment;
    },
    setRotation(value) {
      const rotationValue = value.trim();
      this.secret.rotationIntervalDays = Number(rotationValue)
        ? Number(rotationValue)
        : rotationValue;
    },
    showUpdateToastMessage() {
      const toastMessage = sprintf(
        s__('SecretsManager|Secret %{secretName} was successfully updated.'),
        {
          secretName: this.secret.name,
        },
      );

      this.$emit('show-secrets-toast', toastMessage);
    },
    async submitSecret() {
      if (this.isEditing) {
        this.showConfirmEditModal = true;
      } else {
        await this.createSecret();
      }
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  i18n: {
    fieldRequired: __('This field is required.'),
  },
  modalOptions: {
    actionPrimary: {
      text: __('Save changes'),
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
  secretsIndexRoute: INDEX_ROUTE_NAME,
};
</script>
<template>
  <div>
    <gl-form @submit.prevent="submitSecret">
      <gl-form-group
        v-if="!isEditing"
        data-testid="secret-name-field-group"
        label-for="secret-name"
        :label="__('Name')"
        :description="s__('SecretsManager|The name should be unique within this project.')"
        :invalid-feedback="$options.i18n.fieldRequired"
        :state="secret.name === undefined || isNameValid"
      >
        <gl-form-input
          id="secret-name"
          v-model="secret.name"
          :placeholder="__('Enter a name')"
          :state="secret.name === undefined || isNameValid"
        />
      </gl-form-group>
      <gl-form-group
        data-testid="secret-value-field-group"
        label-for="secret-value"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <template #label>
          {{ __('Value') }}
        </template>
        <gl-form-textarea
          id="secret-value"
          ref="editValueField"
          v-model="secret.secret"
          rows="5"
          max-rows="15"
          no-resize
          :placeholder="valueFieldPlaceholder"
          :spellcheck="false"
          :state="secret.secret === undefined || isValueValid"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Description')"
        data-testid="secret-description-field-group"
        label-for="secret-description"
        :description="s__('SecretsManager|Maximum 200 characters.')"
        :invalid-feedback="
          s__('SecretsManager|This field is required and must be 200 characters or less.')
        "
      >
        <gl-form-input
          id="secret-description"
          v-model.trim="secret.description"
          data-testid="secret-description"
          :placeholder="s__('SecretsManager|Add a description for the secret')"
          :state="secret.description === undefined || isDescriptionValid"
        />
      </gl-form-group>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          :label="__('Environments')"
          label-for="secret-environments"
          class="gl-w-1/2 gl-pr-2"
        >
          <ci-environments-dropdown
            id="secret-environments"
            :are-environments-loading="areEnvironmentsLoading"
            :environments="environments"
            :selected-environment-scope="secret.environment"
            @select-environment="setEnvironment"
            @search-environment-scope="$emit('search-environment', $event)"
          />
        </gl-form-group>
        <gl-form-group :label="__('Branches')" label-for="secret-branches" class="gl-w-1/2 gl-pr-2">
          <secret-branches-field
            label-for="secret-branches"
            :full-path="fullPath"
            :selected-branch="secret.branch"
            @select-branch="setBranch"
          />
        </gl-form-group>
      </div>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          class="gl-w-full"
          label-for="secret-expiration"
          :label="__('Expiration date')"
        >
          <gl-datepicker
            id="secret-expiration"
            v-model="secret.expiration"
            class="gl-max-w-none"
            :placeholder="$options.datePlaceholder"
            :min-date="minExpirationDate"
          />
        </gl-form-group>
        <gl-form-group
          class="gl-w-full"
          :label="s__('SecretRotation|Rotation reminder period')"
          data-testid="secret-rotation-field-group"
          :description="
            s__(
              'SecretRotation|After a set number of days, send a reminder to rotate the secret. Minimum 7 days.',
            )
          "
          label-for="secret-rotation-period"
          optional
          :invalid-feedback="
            s__('SecretRotation|This field must be a number greater than or equal to 7.')
          "
        >
          <gl-form-input
            :value="secret.rotationIntervalDays"
            :state="isRotationValid"
            @input="setRotation"
          />
        </gl-form-group>
      </div>
      <div class="gl-my-3">
        <gl-button
          variant="confirm"
          data-testid="submit-form-button"
          :aria-label="submitButtonText"
          :disabled="!canSubmit || isSubmitting"
          :loading="isSubmitting"
          @click="submitSecret"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :to="{ name: $options.secretsIndexRoute }"
          data-testid="cancel-button"
          class="gl-my-4"
          :aria-label="__('Cancel')"
          :disabled="isSubmitting"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
      <gl-modal
        modal-id="secret-confirm-edit"
        :visible="showConfirmEditModal"
        :title="__('Save changes')"
        :action-primary="$options.modalOptions.actionPrimary"
        :action-secondary="$options.modalOptions.actionSecondary"
        @primary.prevent="editSecret"
        @secondary="hideModal"
        @canceled="hideModal"
        @hidden="hideModal"
      >
        <gl-sprintf
          :message="
            s__(
              `SecretsManager|Are you sure you want to update secret %{secretName}? Saving these changes could cause disruptions, such as loss of access to connected services or failed deployments, if the value is rejected by the services.`,
            )
          "
        >
          <template #secretName>
            <b>{{ secret.name }}</b>
          </template>
        </gl-sprintf>
      </gl-modal>
    </gl-form>
  </div>
</template>
