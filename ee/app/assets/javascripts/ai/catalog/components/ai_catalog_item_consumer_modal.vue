<script>
import { uniqueId } from 'lodash';
import { GlAlert, GlForm, GlFormGroup, GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import FormProjectDropdown from './form_project_dropdown.vue';

const formId = uniqueId('ai-catalog-item-consumer-form-');

export default {
  name: 'AiCatalogItemConsumerModal',
  components: {
    FormProjectDropdown,
    GlAlert,
    GlForm,
    GlFormGroup,
    GlModal,
    GlSprintf,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isOpen: this.open,
      targetId: this.item?.public ? null : this.item?.project?.id || null,
      isDirty: false,
      error: null,
    };
  },
  computed: {
    formId() {
      return formId;
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    title() {
      return sprintf(s__('AICatalog|Enable %{itemType} in a project'), {
        itemType: this.itemTypeLabel,
      });
    },
    projectLabelDescription() {
      return sprintf(s__('AICatalog|Project members will be able to run this %{itemType}.'), {
        itemType: this.itemTypeLabel,
      });
    },
    isPrivateItem() {
      return !this.item.public;
    },
    isProjectValid() {
      return !this.isDirty || this.targetId !== null;
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isProjectValid) {
        return;
      }
      this.isOpen = false;
      this.$emit('submit', { projectId: this.targetId });
    },
  },
  modal: {
    actionPrimary: {
      text: __('Enable'),
      attributes: {
        variant: 'confirm',
        type: 'submit',
        form: formId,
      },
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <gl-modal
    v-model="isOpen"
    modal-id="add-item-consumer-modal"
    :title="title"
    :action-primary="$options.modal.actionPrimary"
    :action-secondary="$options.modal.actionSecondary"
    @primary.prevent
    @hidden="$emit('hide')"
  >
    <gl-alert
      v-if="error"
      data-testid="error-alert"
      variant="danger"
      class="gl-mb-5"
      @dismiss="error = null"
    >
      {{ error }}
    </gl-alert>

    <gl-alert
      v-if="isPrivateItem"
      data-testid="private-alert"
      :dismissible="false"
      variant="info"
      class="gl-mb-5"
    >
      <gl-sprintf
        :message="
          s__(
            'AICatalog|This %{itemType} is private and can only be enabled in the project it was created in. Duplicate the agent to use the same configuration in other projects.',
          )
        "
      >
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
    </gl-alert>

    <dl>
      <dt class="gl-mb-2 gl-font-bold">
        <gl-sprintf :message="s__('AICatalog|Selected %{itemType}')">
          <template #itemType>{{ itemTypeLabel }}</template>
        </gl-sprintf>
      </dt>
      <dd>{{ item.name }}</dd>
    </dl>

    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        v-if="item.public"
        :label="s__('AICatalog|Project')"
        :label-description="projectLabelDescription"
        label-for="target-id"
        :state="isProjectValid"
        :invalid-feedback="s__('AICatalog|Project is required.')"
      >
        <form-project-dropdown
          id="target-id"
          v-model="targetId"
          :is-valid="isProjectValid"
          @error="onError"
        />
      </gl-form-group>

      <dl v-else>
        <dt class="gl-mb-2 gl-font-bold">
          {{ s__('AICatalog|Project') }}
        </dt>
        <dd>
          {{ item.project.nameWithNamespace }}
        </dd>
      </dl>
    </gl-form>
  </gl-modal>
</template>
