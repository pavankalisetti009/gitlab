<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import projectServiceAccountsQuery from '../../../graphql/queries/get_project_service_accounts.query.graphql';
import { FLOW_TRIGGERS_INDEX_ROUTE } from '../../../router/constants';

const MODE_CREATE = 'create';
const MODE_EDIT = 'edit';

export default {
  name: 'AiFlowTriggerForm',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    UserSelect,
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => [MODE_CREATE, MODE_EDIT].includes(mode),
    },
    errorMessages: {
      type: Array,
      required: true,
    },
    eventTypeOptions: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      validator(obj) {
        return ['description', 'eventTypes', 'configPath', 'user'].every((prop) => prop in obj);
      },
      default: () => {
        return {
          description: '',
          eventTypes: [],
          configPath: '',
          user: null,
        };
      },
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      description: this.initialValues.description,
      eventTypes: this.initialValues.eventTypes,
      configPath: this.initialValues.configPath,
      selectedUsers: this.initialValues.user ? [{ ...this.initialValues.user }] : [],
    };
  },
  computed: {
    isEditMode() {
      return this.mode === MODE_EDIT;
    },
    submitButtonText() {
      return this.isEditMode
        ? s__('DuoAgentsPlatform|Save changes')
        : s__('DuoAgentsPlatform|Create flow trigger');
    },
    selectedEventTypeText() {
      const selectedOptions = this.eventTypeOptions
        .filter((option) => option.value in this.eventTypes)
        .map((option) => option.text);
      return (
        selectedOptions.join(', ') || s__('DuoAgentsPlatform|Select one or multiple event types')
      );
    },
    selectedUserName() {
      return this.selectedUsers.length > 0
        ? this.selectedUsers[0].name
        : s__('DuoAgentsPlatform|Select user');
    },
  },
  watch: {
    async errorMessages(newValue) {
      if (newValue.length === 0) {
        return;
      }
      window.scrollTo({
        top: 0,
        left: 0,
        behavior: 'smooth',
      });
    },
  },
  methods: {
    setEventType(eventTypesValue) {
      this.eventTypes = eventTypesValue;
    },
    onUserSelect(users) {
      this.selectedUsers = users;
    },
    onUserSelectError() {
      createAlert({ message: s__('DuoAgentsPlatform|An error occurred while fetching users.') });
    },
    onSubmit() {
      const formValues = {
        configPath: this.configPath.trim(),
        description: this.description.trim(),
        eventTypes: this.eventTypes,
        userId: this.selectedUsers.length > 0 ? this.selectedUsers[0].id : null,
      };
      this.$emit('submit', formValues);
    },
    usersProcessor(data) {
      return data.project?.projectMembers?.nodes?.map(({ user }) => user) || [];
    },
  },
  indexRoute: FLOW_TRIGGERS_INDEX_ROUTE,
  projectServiceAccountsQuery,
};
</script>

<template>
  <div class="lg:gl-w-2/3">
    <gl-alert
      v-if="errorMessages.length"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      @dismiss="$emit('dismiss-errors')"
    >
      <ul class="!gl-mb-0 gl-pl-5">
        <li v-for="(errorMessage, index) in errorMessages" :key="index">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <gl-form @submit.prevent="onSubmit">
      <gl-form-group :label="s__('DuoAgentsPlatform|Description')" label-for="trigger-description">
        <gl-form-textarea
          id="trigger-description"
          v-model="description"
          :placeholder="s__('DuoAgentsPlatform|Enter a description for this flow trigger')"
          required
          rows="1"
        />
      </gl-form-group>

      <gl-form-group :label="s__('DuoAgentsPlatform|Event types')" label-for="trigger-event-type">
        <gl-collapsible-listbox
          id="trigger-event-type"
          :items="eventTypeOptions"
          :selected="eventTypes"
          :toggle-text="selectedEventTypeText"
          :header-text="s__('DuoAgentsPlatform|Select one or multiple event types')"
          :multiple="true"
          block
          @select="setEventType"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('DuoAgentsPlatform|Service account user')"
        label-for="trigger-owner"
      >
        <template #label-description>
          {{ s__('DuoAgentsPlatform|⚠️ Create a unique service account for each project.') }}
          <br />
          {{
            s__(
              'DuoAgentsPlatform|Do not assign the service account a role in your project with higher permissions than the users of that service account.',
            )
          }}
        </template>
        <user-select
          :value="selectedUsers"
          :text="selectedUserName"
          :header-text="s__('DuoAgentsPlatform|Select a service account user')"
          :full-path="projectPath"
          :allow-multiple-assignees="false"
          :custom-search-users-query="$options.projectServiceAccountsQuery"
          :custom-search-users-processor="usersProcessor"
          class="gl-w-full"
          @input="onUserSelect"
          @error="onUserSelectError"
        />
      </gl-form-group>

      <gl-form-group :label="s__('DuoAgentsPlatform|Config path')" label-for="trigger-config-path">
        <gl-form-input
          id="trigger-config-path"
          v-model="configPath"
          :placeholder="s__('DuoAgentsPlatform|Path to configuration file')"
          type="text"
          required
        />
      </gl-form-group>

      <div class="gl-flex gl-flex-wrap gl-gap-3">
        <gl-button
          :loading="isLoading"
          type="submit"
          variant="confirm"
          data-testid="trigger-submit-button"
          class="js-no-auto-disable gl-w-full sm:gl-w-auto"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :to="{ name: $options.indexRoute }"
          :disabled="isLoading"
          class="gl-w-full sm:gl-w-auto"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </gl-form>
  </div>
</template>
