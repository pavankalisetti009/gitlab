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
  },
  data() {
    return {
      isOpen: true,
      targetId: this.item.project?.id || null,
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
      return sprintf(s__('AICatalog|Add this %{itemType} to a project'), {
        itemType: this.itemTypeLabel,
      });
    },
    projectLabelDescription() {
      return sprintf(s__('AICatalog|Select a project to which you want to add this %{itemType}.'), {
        itemType: this.itemTypeLabel,
      });
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    handleSubmit() {
      if (this.targetId === null) {
        this.onError(s__('AICatalog|Project is required.'));
        return;
      }
      this.$emit('submit', { projectId: this.targetId });
    },
  },
  modal: {
    actionPrimary: {
      text: __('Add'),
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
    <gl-alert v-if="error" variant="danger" class="gl-mb-5" @dismiss="error = null">
      {{ error }}
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
        :label="s__('AICatalog|Project')"
        :label-description="projectLabelDescription"
        label-for="target-id"
      >
        <form-project-dropdown id="target-id" v-model="targetId" @error="onError" />
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
