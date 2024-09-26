<script>
import { GlModal, GlDisclosureDropdownItem, GlModalDirective, GlSprintf } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'DeleteSelfHostedModelDisclosureItem',
  components: {
    GlModal,
    GlSprintf,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlModalDirective,
  },
  props: {
    model: {
      type: Object,
      required: true,
    },
  },
  modal: {
    id: 'delete-self-hosted-model-modal',
    actionPrimary: {
      text: __('Delete'),
      attributes: { variant: 'danger' },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
  computed: {
    modelDeploymentName() {
      return { modelName: this.model.name };
    },
  },
  methods: {
    deleteModel() {
      // TODO: Invoke mutation to delete model
    },
  },
};
</script>
<template>
  <div>
    <gl-disclosure-dropdown-item
      v-gl-modal-directive="`delete-${model.name}-model-modal`"
      :aria-label="s__('AdminSelfHostedModels|Delete self-hosted model')"
      variant="danger"
    >
      <template #list-item>
        <span class="gl-text-danger">{{ __('Delete') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-modal
      :modal-id="`delete-${model.name}-model-modal`"
      :title="s__('AdminSelfHostedModels|Delete self-hosted model')"
      size="sm"
      :no-focus-on-show="true"
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="deleteModel"
    >
      <div data-testid="delete-model-confirmation-message">
        <gl-sprintf
          :message="
            sprintf(
              'You are about to delete the %{boldStart}%{modelName}%{boldEnd} self-hosted model. This action cannot be undone.',
              modelDeploymentName,
            )
          "
        >
          <template #bold="{ content }">
            <b>
              {{ content }}
            </b>
          </template>
        </gl-sprintf>
      </div>
      <br />
      {{ __('Are you sure you want to proceed?') }}
    </gl-modal>
  </div>
</template>
