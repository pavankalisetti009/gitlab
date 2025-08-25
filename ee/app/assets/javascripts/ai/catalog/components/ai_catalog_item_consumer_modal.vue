<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormGroup, GlFormInput, GlModal } from '@gitlab/ui';
import { __ } from '~/locale';

const tmpProjectId = 'gid://gitlab/Project/1000000';
const formId = uniqueId('ai-catalog-agent-form-');

export default {
  name: 'AiCatalogItemConsumerModal',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlModal,
  },
  props: {
    flowName: {
      type: String,
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
  },
  methods: {
    handleSubmit() {
      // TODO: This is a tmp solution until we're using
      // a group and project dropdown select instead of an
      // input field.
      const isProjectSelected = this.targetId.toLowerCase().includes('project');
      const isGroupSelected = this.targetId.toLowerCase().includes('group');

      if ((isProjectSelected && isGroupSelected) || (!isProjectSelected && !isGroupSelected)) {
        // eslint-disable-next-line
        console.error(
          // eslint-disable-next-line
          'Invalid State. Target ID must contain either "project" or "group", but not both.',
        );
        return;
      }

      const target = {};

      if (isGroupSelected) {
        target.groupId = this.targetId;
      }

      if (isProjectSelected) {
        target.projectId = this.targetId;
      }

      this.$emit('submit', target);
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
    modal-id="add-flow-to-target"
    :title="s__('AICatalog|Add this flow to a project or a group')"
    :action-primary="$options.modal.actionPrimary"
    :action-secondary="$options.modal.actionSecondary"
    @primary.prevent
    @hidden="$emit('hide')"
  >
    <dl>
      <dt class="gl-mb-2 gl-font-bold">
        {{ s__('AICatalog|Selected flow') }}
      </dt>
      <dd>{{ flowName }}</dd>
    </dl>

    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        :label="s__('AICatalog|Project or Group ID')"
        :label-description="
          s__('AICatalog|Select a project or group for which you want to enable this flow.')
        "
        description="For testing use either 'gid://gitlab/Project/1000000' or 'gid://gitlab/Group/1000000'"
        label-for="target-id"
      >
        <gl-form-input id="target-id" v-model="targetId" required />
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
