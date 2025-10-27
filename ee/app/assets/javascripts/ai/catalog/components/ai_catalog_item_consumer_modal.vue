<script>
import { uniqueId } from 'lodash';
import { GlAlert, GlForm, GlFormGroup, GlFormRadioGroup, GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import {
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_LABELS,
} from '../constants';
import FormGroupDropdown from './form_group_dropdown.vue';
import FormProjectDropdown from './form_project_dropdown.vue';

const formId = uniqueId('ai-catalog-item-consumer-form-');

export default {
  name: 'AiCatalogItemConsumerModal',
  components: {
    FormGroupDropdown,
    FormProjectDropdown,
    GlAlert,
    GlForm,
    GlFormGroup,
    GlFormRadioGroup,
    GlModal,
    GlSprintf,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    showAddToGroup: {
      type: Boolean,
      required: false,
      default: false,
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
      targetId: this.item.public ? null : this.item.project?.id || null,
      targetType:
        this.item.public && this.showAddToGroup
          ? AI_CATALOG_CONSUMER_TYPE_GROUP
          : AI_CATALOG_CONSUMER_TYPE_PROJECT,
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
    targetTypeLabel() {
      return AI_CATALOG_CONSUMER_LABELS[this.targetType];
    },
    title() {
      return sprintf(s__('AICatalog|Enable %{itemType} in a %{targetType}'), {
        itemType: this.itemTypeLabel,
        targetType: this.targetTypeLabel,
      });
    },
    groupLabelDescription() {
      return sprintf(s__('AICatalog|Allows %{itemType} to be enabled in projects.'), {
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
    canAddToGroup() {
      return this.item.public && this.showAddToGroup;
    },
    isTargetValid() {
      return !this.isDirty || this.targetId !== null;
    },
    isTargetTypeGroup() {
      return this.targetType === AI_CATALOG_CONSUMER_TYPE_GROUP;
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isTargetValid) {
        return;
      }
      this.isOpen = false;
      const target = this.isTargetTypeGroup
        ? { groupId: this.targetId }
        : { projectId: this.targetId };
      this.$emit('submit', target);
    },
  },
  targetTypes: [
    {
      value: AI_CATALOG_CONSUMER_TYPE_GROUP,
      text: __('Group'),
    },
    {
      value: AI_CATALOG_CONSUMER_TYPE_PROJECT,
      text: __('Project'),
    },
  ],
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
      <gl-form-group v-if="canAddToGroup" :label="s__('AICatalog|Enable in')">
        <gl-form-radio-group v-model="targetType" :options="$options.targetTypes" />
      </gl-form-group>
      <div v-if="isTargetTypeGroup">
        <gl-form-group
          :label="__('Group')"
          :label-description="groupLabelDescription"
          label-for="group-id"
          :state="isTargetValid"
          :invalid-feedback="s__('AICatalog|Group is required.')"
        >
          <form-group-dropdown
            id="group-id"
            v-model="targetId"
            :is-valid="isTargetValid"
            @error="onError"
          />
        </gl-form-group>
      </div>
      <div v-else>
        <gl-form-group
          v-if="item.public"
          :label="__('Project')"
          :label-description="projectLabelDescription"
          label-for="project-id"
          :state="isTargetValid"
          :invalid-feedback="s__('AICatalog|Project is required.')"
        >
          <form-project-dropdown
            id="project-id"
            v-model="targetId"
            :is-valid="isTargetValid"
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
      </div>
    </gl-form>
  </gl-modal>
</template>
