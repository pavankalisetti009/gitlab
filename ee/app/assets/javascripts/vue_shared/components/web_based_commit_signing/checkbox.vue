<script>
import { GlFormCheckbox, GlAlert } from '@gitlab/ui';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import GroupInheritancePopover from '~/vue_shared/components/settings/group_inheritance_popover.vue';
import getWebBasedCommitSigningQuery from 'ee/graphql_shared/queries/web_based_commit_signing.query.graphql';
import { __ } from '~/locale';

export default {
  name: 'WebBasedCommitSigningCheckbox',
  components: {
    GlFormCheckbox,
    GlAlert,
    GroupInheritancePopover,
  },
  apollo: {
    webBasedCommitSigningEnabled: {
      query: getWebBasedCommitSigningQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          isGroupLevel: this.isGroupLevel,
        };
      },
      update(data) {
        if (this.isGroupLevel) {
          return data.group?.webBasedCommitSigningEnabled ?? false;
        }
        // TODO: Once projectSettings field is added to Project type, uncomment the line below
        // const projectSetting = data.project?.projectSettings?.webBasedCommitSigningEnabled ?? false;
        // For now, only use the group setting for projects (inheritance only)
        return data.project?.group?.webBasedCommitSigningEnabled ?? false;
      },
      skip() {
        return !this.fullPath;
      },
      error(error) {
        this.errorMessage = __('An error occurred while updating the settings.');
        captureException({ error, component: this.$options.name });
      },
    },
  },
  props: {
    hasGroupPermissions: {
      type: Boolean,
      required: true,
    },
    groupSettingsRepositoryPath: {
      type: String,
      required: true,
    },
    isGroupLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      webBasedCommitSigningEnabled: false,
      isSaving: false,
      errorMessage: '',
    };
  },
  computed: {
    isDisabled() {
      // temporarily read-only inherited value for the project-level
      return this.isSaving || !this.isGroupLevel;
    },
  },
  methods: {
    async handleChange(value) {
      // const previousValue = this.webBasedCommitSigningEnabled;
      this.webBasedCommitSigningEnabled = value;
      this.errorMessage = '';
      this.isSaving = true;

      //   TODO: Implement GraphQL mutation and side effects
      // try {
      //   const mutation = this.isGroupLevel
      //     ? updateGroupWebBasedCommitSigningMutation
      //     : updateProjectWebBasedCommitSigningMutation;

      //   const response = await this.$apollo.mutate({
      //     mutation,
      //     variables: {
      //       fullPath: this.fullPath,
      //       webBasedCommitSigningEnabled: value,
      //     },
      //   });
      // } catch (error) {
      //   this.errorMessage = error.message || __('An error occurred while updating the setting.');
      //   this.webBasedCommitSigningEnabled = previousValue;
      // } finally {
      //   this.isSaving = false;
      // }
    },
    dismissError() {
      this.errorMessage = '';
    },
  },
  i18n: {
    label: __('Sign web-based commits'),
    description: __('Automatically sign commits made through the web interface.'),
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-5" @dismiss="dismissError">
      {{ errorMessage }}
    </gl-alert>

    <gl-form-checkbox
      id="web-based-commit-signing-checkbox"
      data-testid="web-based-commit-signing-checkbox"
      :checked="webBasedCommitSigningEnabled"
      :disabled="isDisabled"
      @change="handleChange"
      ><span class="gl-inline-flex">
        {{ $options.i18n.label }}
        <group-inheritance-popover
          v-if="!isGroupLevel"
          class="gl-relative gl-bottom-2"
          :has-group-permissions="hasGroupPermissions"
          :group-settings-repository-path="groupSettingsRepositoryPath"
        />
      </span>
      <template #help>{{ $options.i18n.description }}</template>
    </gl-form-checkbox>
  </div>
</template>
