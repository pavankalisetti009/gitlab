<script>
import { GlButton, GlForm, GlFormGroup, GlFormInput } from '@gitlab/ui';
import { s__, __ } from '~/locale';

export default {
  name: 'StatusCheckForm',
  i18n: {
    serviceNameLabel: s__('StatusChecks|Service name'),
    serviceNameDescription: s__('StatusChecks|Examples: QA, Security, Performance.'),
    apiLabel: s__('StatusChecks|API to check'),
    apiDescription: s__('StatusChecks|Invoke an external API as part of the pipeline process.'),
    saveChanges: __('Save changes'),
    cancel: __('Cancel'),
  },
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
  },
  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      serviceName: '',
      apiUrl: '',
    };
  },
  methods: {
    submit() {
      // TODO: add check for validations
      this.$emit('saveChanges');
    },
  },
  serviceNameInput: 'service-name-input',
  apiUrlInput: 'api-url-input',
  apiPlaceholderText: 'https://api.gitlab.com',
};
</script>

<template>
  <gl-form novalidate @submit.prevent="submit">
    <gl-form-group
      :label="$options.i18n.serviceNameLabel"
      :label-for="$options.serviceNameInput"
      :description="$options.i18n.serviceNameDescription"
      class="gl-border-none"
    >
      <gl-form-input :id="$options.serviceNameInput" :value="serviceName" />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.apiLabel"
      :label-for="$options.apiUrlInput"
      :description="$options.i18n.apiDescription"
      class="gl-border-none"
    >
      <gl-form-input
        :id="$options.apiUrlInput"
        :value="apiUrl"
        :placeholder="$options.apiPlaceholderText"
      />
    </gl-form-group>

    <div class="gl-flex gl-gap-3">
      <gl-button
        variant="confirm"
        data-testid="save-btn"
        :loading="isLoading"
        type="submit"
        @click="submit"
      >
        {{ $options.i18n.saveChanges }}
      </gl-button>
      <gl-button
        variant="confirm"
        data-testid="cancel-btn"
        category="secondary"
        @click="$emit('close')"
      >
        {{ $options.i18n.cancel }}
      </gl-button>
    </div>
  </gl-form>
</template>
