<script>
import { GlForm, GlButton, GlCollapsibleListbox, GlFormFields } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/dist/utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import InputCopyToggleVisibility from '~/vue_shared/components/form/input_copy_toggle_visibility.vue';

export default {
  name: 'SelfHostedModelForm',
  components: {
    GlForm,
    GlButton,
    GlCollapsibleListbox,
    GlFormFields,
    InputCopyToggleVisibility,
  },
  props: {
    basePath: {
      type: String,
      required: true,
    },
    modelOptions: {
      type: Array,
      required: true,
    },
    submitButtonText: {
      type: String,
      required: false,
      default: s__('AdminSelfHostedModels|Create self-hosted model'),
    },
    mutationData: {
      type: Object,
      required: true,
    },
    initialFormValues: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    defaultError: s__(
      'AdminSelfHostedModels|There was an error saving the self-hosted model. Please try again.',
    ),
    missingDeploymentNameError: s__('AdminSelfHostedModels|Please enter a deployment name.'),
    missingEndpointError: s__('AdminSelfHostedModels|Please enter an endpoint.'),
    modelNotSelectedError: s__('AdminSelfHostedModels|Please select a model.'),
    nonUniqueDeploymentNameError: s__(
      'AdminSelfHostedModels|Please enter a unique deployment name.',
    ),
    invalidEndpointError: s__('AdminSelfHostedModels|Please add a valid endpoint.'),
  },
  formId: 'self-hosted-model-form',
  data() {
    const { name = '', model = '', endpoint = '', apiToken = '' } = this.initialFormValues;
    const modelToUpperCase = model.toUpperCase();

    return {
      fields: {
        name: {
          label: s__('AdminSelfHostedModels|Deployment name'),
          validators: [formValidators.required(this.$options.i18n.missingDeploymentNameError)],
        },
        model: {
          label: s__('AdminSelfHostedModels|Model'),
          validators: [formValidators.required(this.$options.i18n.modelNotSelectedError)],
        },
        endpoint: {
          label: s__('AdminSelfHostedModels|Endpoint'),
          validators: [formValidators.required(this.$options.i18n.missingEndpointError)],
        },
      },
      baseFormValues: {
        name,
        endpoint,
        model: modelToUpperCase,
      },
      apiToken,
      selectedModel: {
        modelValue: model || '',
        modelName:
          this.modelOptions.find(({ modelValue }) => modelValue === model.toUpperCase())
            ?.modelName || '',
      },
      serverValidations: {},
      isSaving: false,
    };
  },
  computed: {
    availableModels() {
      return this.modelOptions.map((modelOptions) => ({
        value: modelOptions.modelValue,
        text: modelOptions.modelName,
      }));
    },
    dropdownToggleText() {
      return this.selectedModel.modelName || s__('AdminSelfHostedModels|Select model');
    },
    hasValidInput() {
      return (
        this.baseFormValues.name !== '' &&
        this.baseFormValues.model !== '' &&
        this.baseFormValues.endpoint !== ''
      );
    },
    isEditing() {
      return Boolean(this.initialFormValues.id);
    },
  },
  methods: {
    async onSubmit() {
      if (!this.hasValidInput) return;

      const { mutation } = this.mutationData;

      const formValues = {
        apiToken: this.apiToken,
        ...this.baseFormValues,
        ...(this.isEditing
          ? {
              id: convertToGraphQLId('Ai::SelfHostedModel', this.initialFormValues.id),
            }
          : {}),
      };

      this.isSaving = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              ...formValues,
            },
          },
        });
        if (data) {
          const { errors } = data[this.mutationData.name];
          if (errors.length > 0) {
            this.onError(errors);
            this.isSaving = false;
            return;
          }

          // TODO: Implement router to handle page transitions
          this.isSaving = false;
          visitUrl(this.basePath);
        }
      } catch (error) {
        createAlert({
          message: this.$options.i18n.defaultError,
          error,
          captureError: true,
        });
        this.isSaving = false;
      }
    },
    onSelect(model) {
      this.onInputField({ name: 'model' });
      this.selectedModel = this.modelOptions.find((item) => item.modelValue === model);
      this.baseFormValues.model = this.selectedModel.modelValue;
    },
    // clears the validation error
    onInputField({ name }) {
      delete this.serverValidations[name];
    },
    onClick(event) {
      event.currentTarget.blur();
    },
    onError(errors) {
      // TODO: Delegate sorting of errors to the back-end - the client should only need to consume these
      const error = errors[0];
      const SERVER_VALIDATION_ERRORS = {
        /* eslint-disable @gitlab/require-i18n-strings */
        name: 'Name has already been taken',
        endpoint: 'Endpoint is blocked',
        /* eslint-enable @gitlab/require-i18n-strings */
      };

      if (error.includes(SERVER_VALIDATION_ERRORS.endpoint)) {
        this.serverValidations = {
          ...this.serverValidations,
          endpoint: this.$options.i18n.invalidEndpointError,
        };
      }
      if (error.includes(SERVER_VALIDATION_ERRORS.name)) {
        this.serverValidations = {
          ...this.serverValidations,
          name: this.$options.i18n.nonUniqueDeploymentNameError,
        };
      }

      // Unrecognised error, display generic error message
      if (
        !error.includes(SERVER_VALIDATION_ERRORS.name) &&
        !error.includes(SERVER_VALIDATION_ERRORS.endpoint)
      ) {
        throw new Error(error);
      }
    },
  },
};
</script>
<template>
  <gl-form :id="$options.formId" class="gl-max-w-48" @submit.prevent="onSubmit">
    <gl-form-fields
      v-model="baseFormValues"
      :fields="fields"
      :form-id="$options.formId"
      :server-validations="serverValidations"
      @input-field="onInputField"
      @submit="$emit('submit', baseFormValues)"
    >
      <template #input(model)>
        <gl-collapsible-listbox
          :items="availableModels"
          block
          fluid-width
          :toggle-text="dropdownToggleText"
          :selected="selectedModel.modelName"
          @select="onSelect"
        />
      </template>
    </gl-form-fields>
    <input-copy-toggle-visibility
      v-model="apiToken"
      :value="apiToken"
      :label="s__('AdminSelfHostedModels|API Key (optional)')"
      :initial-visibility="false"
      :disabled="isSaving"
      :show-copy-button="false"
    />
    <div class="gl-pt-5">
      <gl-button
        type="submit"
        variant="confirm"
        class="js-no-auto-disable gl-mr-3"
        :loading="isSaving"
        @click="onClick"
      >
        {{ submitButtonText }}
      </gl-button>
      <gl-button :href="basePath">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </gl-form>
</template>
