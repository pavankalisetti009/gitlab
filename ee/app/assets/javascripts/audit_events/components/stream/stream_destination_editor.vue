<script>
import { GlAlert, GlForm, GlFormGroup, GlFormInput, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import {
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from '../../constants';
import { getFormattedFormItem } from '../../utils';
import StreamDestinationEditorHttpFields from './stream_destination_editor_http_fields.vue';
import StreamDestinationEditorAwsFields from './stream_destination_editor_aws_fields.vue';
import StreamDestinationEditorGcpFields from './stream_destination_editor_gcp_fields.vue';
import StreamEventTypeFilters from './stream_event_type_filters.vue';
import StreamNamespaceFilters from './stream_namespace_filters.vue';
import StreamDeleteModal from './stream_delete_modal.vue';

export default {
  name: 'StreamDestinationEditor',
  components: {
    GlAlert,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlButton,
    StreamDestinationEditorHttpFields,
    StreamDestinationEditorAwsFields,
    StreamDestinationEditorGcpFields,
    StreamEventTypeFilters,
    StreamNamespaceFilters,
    StreamDeleteModal,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      formItem: getFormattedFormItem(this.item),
      loading: false,
      errors: [],
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.item.id);
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    isSubmitButtonDisabled() {
      if (!this.formItem.name || this.formItem.shouldDisableSubmitButton) {
        return true;
      }

      return this.hasNoChanges;
    },
    hasNoChanges() {
      return (
        JSON.stringify(this.item.config) === JSON.stringify(this.formItem.config) &&
        this.item.secretToken === this.formItem.secretToken &&
        this.item.name === this.formItem.name
      );
    },
    submitButtonName() {
      return this.isEditing
        ? s__('AuditStreams|Save external stream destination')
        : s__('AuditStreams|Add external stream destination');
    },
    submitButtonText() {
      return this.isEditing ? __('Save') : __('Add');
    },
  },
  watch: {
    item: {
      handler(newItem) {
        this.formItem = getFormattedFormItem(newItem);
      },
      deep: true,
    },
  },
  methods: {
    onDeleting() {
      this.loading = true;
    },
    onDelete() {
      this.$emit('deleted', this.item.id);
      this.loading = false;
    },
    onDeleteError(error) {
      this.loading = false;
      this.errors.push(
        s__(
          'AuditStreams|An error occurred when deleting external audit event stream destination. Please try it again.',
        ),
      );
      Sentry.captureException(error);
      this.$emit('error');
    },
    clearError(index) {
      this.errors.splice(index, 1);
    },
    deleteDestination() {
      this.$refs.deleteModal.show();
    },
    formSubmission() {
      // To be updated in the next MR
      // part of https://gitlab.com/gitlab-org/gitlab/-/issues/524939
      // FF use_consolidated_audit_event_stream_dest_api
      // return this.isEditing
      //   ? console.log('update', this.formItem)
      //   : console.log('add', this.formItem);
    },
  },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
};
</script>

<template>
  <div class="gl-pb-5 gl-pl-6 gl-pr-0">
    <gl-alert
      v-if="!isEditing"
      :title="s__('AuditStreams|Destinations receive all audit event data')"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="data-warning"
      variant="warning"
    >
      {{
        s__(
          'AuditStreams|This could include sensitive information. Make sure you trust the destination endpoint.',
        )
      }}
    </gl-alert>

    <gl-alert
      v-for="(error, index) in errors"
      :key="index"
      :dismissible="true"
      class="gl-mb-5"
      data-testid="alert-errors"
      variant="danger"
      @dismiss="clearError(index)"
    >
      {{ error }}
    </gl-alert>

    <gl-form @submit.prevent="formSubmission">
      <gl-form-group
        :label="s__('AuditStreams|Destination Name')"
        data-testid="destination-name-form-group"
      >
        <gl-form-input v-model="formItem.name" data-testid="destination-name" />
      </gl-form-group>

      <stream-destination-editor-http-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_HTTP"
        v-model="formItem"
        :is-editing="isEditing"
        :loading="loading"
      />

      <stream-destination-editor-aws-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_AMAZON_S3"
        v-model="formItem"
        :is-editing="isEditing"
      />

      <stream-destination-editor-gcp-fields
        v-if="formItem.category === $options.DESTINATION_TYPE_GCP_LOGGING"
        v-model="formItem"
        :is-editing="isEditing"
      />

      <div class="gl-mb-5">
        <label class="gl-block gl-text-lg" data-testid="filtering-header">{{
          s__('AuditStreams|Event filtering (optional)')
        }}</label>
        <div>
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-type-filter"
            data-testid="event-type-filtering-header"
            >{{ s__('AuditStreams|Filter by audit event type') }}</label
          >
          <stream-event-type-filters v-model="formItem.eventTypeFilters" />
        </div>
        <div v-if="!isInstance">
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-namespace-filter"
            data-testid="event-namespace-filtering-header"
            >{{ s__('AuditStreams|Filter by groups or projects') }}</label
          >
          <stream-namespace-filters v-model="formItem.namespaceFilter" />
        </div>
      </div>
      <div class="gl-flex">
        <gl-button
          :disabled="isSubmitButtonDisabled"
          :loading="loading"
          :name="submitButtonName"
          class="gl-mr-3"
          variant="confirm"
          type="submit"
          data-testid="stream-destination-submit-button"
          >{{ submitButtonText }}</gl-button
        >
        <gl-button
          :name="__('Cancel editing')"
          data-testid="stream-destination-cancel-button"
          @click="$emit('cancel')"
          >{{ __('Cancel') }}</gl-button
        >
        <gl-button
          v-if="isEditing"
          :name="s__('AuditStreams|Delete destination')"
          :loading="loading"
          variant="danger"
          class="gl-ml-auto"
          data-testid="stream-destination-delete-button"
          @click="deleteDestination"
          >{{ s__('AuditStreams|Delete destination') }}</gl-button
        >
      </div>
    </gl-form>
    <stream-delete-modal
      v-if="isEditing"
      ref="deleteModal"
      :type="item.category"
      :item="item"
      @deleting="onDeleting"
      @delete="onDelete"
      @error="onDeleteError"
    />
  </div>
</template>
