<script>
import { GlModal, GlDisclosureDropdownItem, GlModalDirective, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
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
  inject: ['aiFeatureSettingsPath'],
  props: {
    model: {
      type: Object,
      required: true,
    },
  },
  canDeleteModal: {
    actionPrimary: {
      text: __('Delete'),
      attributes: { variant: 'danger' },
    },
    actionCancel: {
      text: __('Cancel'),
    },
    title: s__('AdminSelfHostedModels|Delete self-hosted model'),
  },
  cannotDeleteModal: {
    actionPrimary: {
      text: s__('AdminSelfHostedModels|Configure AI Features'),
    },
    title: s__('AdminSelfHostedModels|This self-hosted model cannot be deleted'),
    actionCancel: {
      text: __('Okay'),
    },
  },
  i18n: {
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
    featureSettings() {
      return this.model.featureSettings?.nodes || [];
    },
    canDelete() {
      return this.featureSettings.length === 0;
    },
    modal() {
      return this.canDelete ? this.$options.canDeleteModal : this.$options.cannotDeleteModal;
    },
    primarySelected() {
      return this.canDelete ? this.deleteModel : this.goToFeatureSettingPage;
    },
    modalPrimaryAction() {
      // Return a primary action only if the model is able to be deleted.
      return this.canDelete ? this.modal.actionPrimary : null;
    },
  },
  methods: {
    async goToFeatureSettingPage() {
      return visitUrl(this.aiFeatureSettingsPath);
    },
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
    <!--
      TODO:
      Since switching to tabbed pages in SelfHostedDuoConfiguration, the aiFeatureSettingsPath
      will no longer work as it leads to the old page. There is currently no alternative as we
      don't support tabbed routes yet. Support will be added in 17.6
      https://gitlab.com/gitlab-org/gitlab/-/issues/497718. Until then we can
      remove the CTA button linking the route when displaying the cannotDeleteModal.
    -->
    <gl-modal
      :modal-id="`delete-${model.name}-model-modal`"
      :title="modal.title"
      size="sm"
      :no-focus-on-show="true"
      :action-primary="modalPrimaryAction"
      :action-cancel="modal.actionCancel"
      @primary="primarySelected"
    >
      <div v-if="canDelete">
        <div data-testid="delete-model-confirmation-message">
          <gl-sprintf
            :message="
              sprintf(
                s__(
                  'AdminSelfHostedModels|You are about to delete the %{boldStart}%{modelName}%{boldEnd} self-hosted model. This action cannot be undone.',
                ),
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
      </div>
      <div v-else>
        <p>
          <gl-sprintf
            :message="
              sprintf(
                s__(
                  'AdminSelfHostedModels|To remove %{boldStart}%{modelName}%{boldEnd}, you must first remove it from the following AI Feature(s):',
                ),
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
        </p>
        <ul>
          <li v-for="feature in featureSettings" :key="feature.feature">
            {{ feature.feature }}
          </li>
        </ul>
        <p>
          {{
            s__(
              'AdminSelfHostedModels|Once the model is no longer in use, you can return here to delete it.',
            )
          }}
        </p>
      </div>
    </gl-modal>
  </div>
</template>
