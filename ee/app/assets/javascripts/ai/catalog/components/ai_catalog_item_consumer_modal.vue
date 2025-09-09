<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormGroup, GlFormInput, GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { AI_CATALOG_ITEM_LABELS } from '../constants';

const tmpProjectId = 'gid://gitlab/Project/1000000';
const formId = uniqueId('ai-catalog-item-consumer-form-');

export default {
  name: 'AiCatalogItemConsumerModal',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
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
      targetId: tmpProjectId,
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
    handleSubmit() {
      // TODO: This is a tmp solution until we're using
      // a project dropdown select instead of an
      // input field.
      const isProjectSelected = this.targetId.toLowerCase().includes('project');

      if (!isProjectSelected) {
        // eslint-disable-next-line
        console.error(
          // eslint-disable-next-line
          'Invalid State. Target ID must contain "project"',
        );
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
        :label="s__('AICatalog|Project ID')"
        :label-description="projectLabelDescription"
        description="For testing use 'gid://gitlab/Project/1000000'"
        label-for="target-id"
      >
        <gl-form-input id="target-id" v-model="targetId" required />
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
