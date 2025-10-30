<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadioGroup,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { scrollTo } from '~/lib/utils/scroll_utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { createAvailableFlowItemTypes } from 'ee/ai/catalog/utils';
import getCatalogConsumerItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_catalog_consumer_items.query.graphql';
import projectServiceAccountsQuery from '../../../graphql/queries/get_project_service_accounts.query.graphql';
import { FLOW_TRIGGERS_INDEX_ROUTE } from '../../../router/constants';
import AiLegalDisclaimer from '../../../components/common/ai_legal_disclaimer.vue';

const MODE_CREATE = 'create';
const MODE_EDIT = 'edit';

const CONFIG_MODE_CATALOG = 'catalog';
const CONFIG_MODE_FILE_PATH = 'manual';

export default {
  name: 'AiFlowTriggerForm',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlForm,
    GlFormGroup,
    GlFormRadioGroup,
    GlFormInput,
    GlFormTextarea,
    UserSelect,
    ErrorsAlert,
    AiLegalDisclaimer,
  },
  mixins: [glFeatureFlagsMixin()],
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
        return ['description', 'eventTypes', 'configPath', 'user', 'aiCatalogItemConsumer'].every(
          (prop) => prop in obj,
        );
      },
      default: () => {
        return {
          description: '',
          eventTypes: [],
          configPath: '',
          user: null,
          aiCatalogItemConsumer: {},
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
    projectId: {
      type: String,
      required: true,
    },
  },
  apollo: {
    catalogItems: {
      query: getCatalogConsumerItemsQuery,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          itemTypes: this.catalogItemTypes,
        };
      },
      skip() {
        return !this.isCatalogConfigModeAvailable;
      },
      update(data) {
        return (
          data.aiCatalogConfiguredItems?.nodes.map((catalogItem) => ({
            id: catalogItem.id,
            name: catalogItem.item.name,
          })) || []
        );
      },
      error() {
        this.errors.push(
          s__(
            'DuoAgentsPlatform|An error occurred while fetching flows configured for this project.',
          ),
        );
      },
    },
  },
  data() {
    return {
      catalogItems: [],
      errors: [],
      configMode:
        // Only use CATALOG mode if it's available AND (there's a consumer ID OR no existing config path)
        // Otherwise, use FILE_PATH mode
        (this.glFeatures.aiCatalogFlows || this.glFeatures.aiCatalogThirdPartyFlows) &&
        (this.initialValues.aiCatalogItemConsumer.id || !this.initialValues.configPath)
          ? CONFIG_MODE_CATALOG
          : CONFIG_MODE_FILE_PATH,
      configPath: this.initialValues.configPath,
      description: this.initialValues.description,
      eventTypes: this.initialValues.eventTypes,
      selectedFlow: this.initialValues.aiCatalogItemConsumer.id,
      selectedUsers: this.initialValues.user ? [{ ...this.initialValues.user }] : [],
    };
  },
  computed: {
    catalogItemTypes() {
      return createAvailableFlowItemTypes({
        isFlowsEnabled: this.glFeatures.aiCatalogFlows,
        isThirdPartyFlowsEnabled: this.glFeatures.aiCatalogThirdPartyFlows,
      });
    },
    isCatalogConfigModeAvailable() {
      return this.catalogItemTypes.length > 0;
    },
    isCatalogConfigMode() {
      return this.configMode === CONFIG_MODE_CATALOG;
    },
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
        .filter((option) => this.eventTypes.includes(option.value))
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
    selectedCatalogItem() {
      return this.catalogItems.find((item) => {
        return item.id === this.selectedFlow;
      });
    },
    catalogItemOptions() {
      return this.catalogItems.map((catalogConsumerItem) => ({
        value: catalogConsumerItem.id,
        text: catalogConsumerItem.name,
      }));
    },
    selectedFlowText() {
      return (
        this.selectedCatalogItem?.name ?? s__('DuoAgentsPlatform|Select a flow from the AI Catalog')
      );
    },
  },
  watch: {
    async errorMessages(newValue) {
      if (newValue.length === 0) {
        return;
      }
      scrollTo(
        {
          top: 0,
          left: 0,
          behavior: 'smooth',
        },
        this.$el,
      );
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
      this.errors.push(s__('DuoAgentsPlatform|An error occurred while fetching users.'));
    },
    setSelectedFlow(selectedValue) {
      this.selectedFlow = selectedValue;
    },
    onSubmit() {
      const formValues = {
        description: this.description.trim(),
        eventTypes: this.eventTypes,
        userId: this.selectedUsers.length > 0 ? this.selectedUsers[0].id : null,
        configPath: this.isCatalogConfigMode ? '' : this.configPath.trim(),
        aiCatalogItemConsumerId: this.isCatalogConfigMode ? this.selectedFlow : null,
      };

      this.$emit('submit', formValues);
    },
    usersProcessor(data) {
      return data.project?.projectMembers?.nodes?.map(({ user }) => user) || [];
    },
    dismissErrors() {
      this.errors = [];
    },
  },
  indexRoute: FLOW_TRIGGERS_INDEX_ROUTE,
  projectServiceAccountsQuery,
  configModeOptions: [
    { value: CONFIG_MODE_CATALOG, text: s__('DuoAgentsPlatform|AI Catalog') },
    { value: CONFIG_MODE_FILE_PATH, text: s__('DuoAgentsPlatform|Configuration path') },
  ],
};
</script>

<template>
  <div class="@lg/panel:gl-w-2/3">
    <errors-alert :errors="errors" alert-class="gl-mb-3 gl-mt-5" @dismiss="dismissErrors" />
    <gl-alert
      v-if="errorMessages.length"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      data-testid="error-messages-alert"
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
          data-testid="trigger-event-type-listbox"
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
          <br />
          {{
            s__(
              'DuoAgentsPlatform|Once the service account is configured for use with flow triggers, it cannot be used for other things.',
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

      <gl-form-group
        v-if="isCatalogConfigModeAvailable"
        :label="s__('DuoAgentsPlatform|Configuration source')"
        label-for="config-mode"
      >
        <gl-form-radio-group
          id="config-mode"
          v-model="configMode"
          :options="$options.configModeOptions"
        />
      </gl-form-group>

      <template v-if="isCatalogConfigMode">
        <gl-form-group :label="s__('DuoAgentsPlatform|Flow')" label-for="trigger-agent">
          <template #label-description>
            {{
              s__(
                'DuoAgentsPlatform|From the flows configured for this project, select the flow that this trigger will execute.',
              )
            }}
          </template>
          <gl-collapsible-listbox
            id="trigger-agent"
            :items="catalogItemOptions"
            :selected="selectedFlow"
            :toggle-text="selectedFlowText"
            :header-text="s__('DuoAgentsPlatform|Select a flow from the AI Catalog')"
            :loading="$apollo.queries.catalogItems.loading"
            block
            searchable
            data-testid="trigger-agent-listbox"
            @select="setSelectedFlow"
          />
        </gl-form-group>
      </template>
      <gl-form-group
        v-else
        :label="s__('DuoAgentsPlatform|Configuration path')"
        label-for="trigger-config-path"
      >
        <template #label-description>
          {{ s__('DuoAgentsPlatform|Enter the path to your configuration file.') }}
        </template>
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
          class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :to="{ name: $options.indexRoute }"
          :disabled="isLoading"
          class="gl-w-full @sm/panel:gl-w-auto"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
      <ai-legal-disclaimer />
    </gl-form>
  </div>
</template>
