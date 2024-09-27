<script>
import { GlModal, GlDisclosureDropdownItem, GlModalDirective, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import deleteSelfHostedModelMutation from '../graphql/mutations/delete_self_hosted_model.mutation.graphql';
import getSelfHostedModelsQuery from '../graphql/queries/get_self_hosted_models.query.graphql';

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
  i18n: {
    modalTitle: s__('AdminSelfHostedModels|Delete self-hosted model'),
    successMessage: s__('AdminSelfHostedModels|Your self-hosted model was successfully deleted.'),
    defaultErrorMessage: s__(
      'AdminSelfHostedModels|An error occurred while deleting your self-hosted model. Please try again.',
    ),
  },
  data() {
    return {
      isDeleting: false,
    };
  },
  computed: {
    modelDeploymentName() {
      return { modelName: this.model.name };
    },
  },
  methods: {
    async deleteModel() {
      this.isDeleting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteSelfHostedModelMutation,
          variables: {
            input: {
              id: this.model.id,
            },
          },
          refetchQueries: [
            {
              query: getSelfHostedModelsQuery,
            },
          ],
        });

        if (data) {
          const errors = data.aiSelfHostedModelDelete?.errors;

          if (errors.length > 0) {
            throw new Error(errors[0]);
          }
        }

        this.isDeleting = false;
        createAlert({
          message: this.$options.i18n.successMessage,
          variant: 'success',
        });
      } catch (error) {
        this.isDeleting = false;
        createAlert({
          message: error?.message || this.$options.i18n.defaultErrorMessage,
          error,
          captureError: true,
        });
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-disclosure-dropdown-item
      v-gl-modal-directive="`delete-${model.name}-model-modal`"
      :aria-label="$options.i18n.modalTitle"
      variant="danger"
    >
      <template #list-item>
        <span class="gl-text-danger">{{ __('Delete') }}</span>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-modal
      :modal-id="`delete-${model.name}-model-modal`"
      :title="$options.i18n.modalTitle"
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
