<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
  GlLink,
  GlModalDirective,
  GlTooltipDirective,
  GlSprintf,
} from '@gitlab/ui';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';
import { s__, sprintf } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import {
  AI_CATALOG_ITEM_LABELS,
  DELETE_OPTIONS,
  TRACK_EVENT_ENABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_ITEM_TYPES,
  TRACK_EVENT_ORIGIN_EXPLORE,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_PAGE_SHOW,
} from '../constants';
import aiCatalogProjectUserPermissionsQuery from '../graphql/queries/ai_catalog_project_user_permissions.query.graphql';
import AiCatalogItemConsumerModal from './ai_catalog_item_consumer_modal.vue';
import AiCatalogItemReportModal from './ai_catalog_item_report_modal.vue';

export default {
  name: 'AiCatalogItemActions',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlLink,
    GlSprintf,
    ConfirmActionModal,
    AiCatalogItemConsumerModal,
    AiCatalogItemReportModal,
    AddProjectItemConsumerModal,
  },
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    isGlobal: {
      default: false,
    },
    projectPath: {
      default: null,
    },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    itemRoutes: {
      type: Object,
      required: true,
    },
    isAgentsAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    isFlowsAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasParentConsumer: {
      type: Boolean,
      required: false,
      default: false,
    },
    disableFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    deleteFn: {
      type: Function,
      required: false,
      default: () => {},
    },
    disableConfirmMessage: {
      type: String,
      required: false,
      default: null,
    },
    enableModalTexts: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['add-to-target', 'report-item'],
  data() {
    return {
      showDeleteModal: false,
      showDisableModal: false,
      forceHardDelete: false,
      projectUserPermissions: {},
    };
  },
  apollo: {
    projectUserPermissions: {
      query: aiCatalogProjectUserPermissionsQuery,
      skip() {
        return !this.projectPath;
      },
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update: (data) => data.project?.userPermissions || {},
    },
  },
  computed: {
    canAdmin() {
      return Boolean(this.item.userPermissions?.adminAiCatalogItem);
    },
    canAdminConsumer() {
      return Boolean(this.projectUserPermissions?.adminAiCatalogItemConsumer);
    },
    canReport() {
      return Boolean(this.item.userPermissions?.reportAiCatalogItem);
    },
    canHardDelete() {
      return Boolean(this.item.userPermissions?.forceHardDeleteAiCatalogItem);
    },
    canUse() {
      return isLoggedIn();
    },
    isEnabled() {
      return this.item.configurationForProject?.enabled;
    },
    showDisable() {
      return this.canAdminConsumer && !this.isGlobal && this.isEnabled;
    },
    showEnable() {
      return this.canAdminConsumer && !this.isGlobal && !this.isEnabled;
    },
    showDuplicate() {
      return this.canUse && (this.isGlobal || this.canAdmin);
    },
    showDropdown() {
      return this.canAdmin || this.canAdminConsumer || this.showDuplicate || this.canReport;
    },
    showAddToProject() {
      return this.canUse && this.isGlobal && !this.item.foundational;
    },
    showAddToGroup() {
      return (
        this.canUse &&
        this.isGlobal &&
        (this.isFlowsAvailable || this.isAgentsAvailable) &&
        !this.item.foundational
      );
    },
    duplicateItemProps() {
      return {
        text: s__('AICatalog|Duplicate'),
        to: {
          name: this.itemRoutes.duplicate,
          params: { id: this.$route.params.id },
        },
      };
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    disableConfirmTitle() {
      return sprintf(s__('AICatalog|Disable %{itemType}'), {
        itemType: this.itemTypeLabel,
      });
    },
    deleteConfirmTitle() {
      return sprintf(s__('AICatalog|Delete %{itemType}'), {
        itemType: this.itemTypeLabel,
      });
    },
    deleteConfirmMessage() {
      return s__('AICatalog|Are you sure you want to delete %{itemType} %{name}?');
    },
    pendingMessage() {
      return !this.hasParentConsumer
        ? sprintf(
            s__(
              'AICatalog|This %{itemType} requires approval from your parent group owner before it can be used',
            ),
            {
              itemType: this.itemTypeLabel,
            },
          )
        : null;
    },
    useAddProjectModal() {
      return !this.isGlobal;
    },
    enableModalComponent() {
      return this.useAddProjectModal ? AddProjectItemConsumerModal : AiCatalogItemConsumerModal;
    },
    enableModalProps() {
      return this.useAddProjectModal
        ? {
            itemTypes: [this.item.itemType],
            modalTexts: this.enableModalTexts,
          }
        : { isProjectNamespace: this.showEnable };
    },
    deleteOptions() {
      return DELETE_OPTIONS(this.itemTypeLabel);
    },
  },
  methods: {
    onClickEnable() {
      this.trackEvent(TRACK_EVENT_ENABLE_AI_CATALOG_ITEM, {
        label: TRACK_EVENT_ITEM_TYPES[this.item.itemType],
        origin: this.isGlobal ? TRACK_EVENT_ORIGIN_EXPLORE : TRACK_EVENT_ORIGIN_PROJECT,
        page: TRACK_EVENT_PAGE_SHOW,
      });
    },
    openDeleteModal() {
      this.forceHardDelete = this.canHardDelete;
      this.showDeleteModal = true;
    },
  },
  adminModeDocsLink: helpPagePath('/administration/settings/sign_in_restrictions', {
    anchor: 'admin-mode',
  }),
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <gl-button
      v-if="canAdmin"
      :to="{ name: itemRoutes.edit, params: { id: $route.params.id } }"
      category="secondary"
      icon="pencil"
      data-testid="edit-button"
    >
      {{ __('Edit') }}
    </gl-button>
    <gl-button
      v-if="showAddToGroup"
      v-gl-modal="'enable-item-modal'"
      variant="confirm"
      category="primary"
      data-testid="add-to-group-button"
      @click="onClickEnable"
    >
      {{ s__('AICatalog|Enable in group') }}
    </gl-button>
    <gl-button
      v-else-if="showAddToProject"
      v-gl-modal="'enable-item-modal'"
      variant="confirm"
      category="primary"
      data-testid="add-to-project-button"
      @click="onClickEnable"
    >
      {{ s__('AICatalog|Enable in project') }}
    </gl-button>
    <span v-else-if="showEnable" v-gl-tooltip="!hasParentConsumer" :title="pendingMessage">
      <gl-button
        v-gl-modal="'enable-item-modal'"
        :disabled="!hasParentConsumer"
        variant="confirm"
        category="primary"
        data-testid="enable-button"
        @click="onClickEnable"
      >
        {{ __('Enable') }}
      </gl-button>
    </span>
    <gl-disclosure-dropdown
      v-if="showDropdown"
      :toggle-text="__('More actions')"
      category="tertiary"
      icon="ellipsis_v"
      no-caret
      text-sr-only
      data-testid="more-actions-dropdown"
    >
      <gl-disclosure-dropdown-item
        v-if="showDuplicate"
        :item="duplicateItemProps"
        data-testid="duplicate-button"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="duplicate" variant="current" aria-hidden="true" />
            {{ s__('AICatalog|Duplicate') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item
        v-if="showDisable"
        data-testid="disable-button"
        @action="showDisableModal = true"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="cancel" variant="current" aria-hidden="true" />
            {{ __('Disable') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item
        v-if="canReport"
        v-gl-modal="'ai-catalog-item-report-modal'"
        variant="danger"
        data-testid="report-button"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="flag" variant="current" aria-hidden="true" />
            {{ s__('AICatalog|Report to admin') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
      <gl-disclosure-dropdown-item
        v-if="canAdmin"
        variant="danger"
        data-testid="delete-button"
        @action="openDeleteModal"
      >
        <template #list-item>
          <span class="gl-flex gl-gap-2">
            <gl-icon name="remove" variant="current" aria-hidden="true" />
            {{ __('Delete') }}
          </span>
        </template>
      </gl-disclosure-dropdown-item>
    </gl-disclosure-dropdown>
    <confirm-action-modal
      v-if="canAdmin && showDeleteModal"
      modal-id="delete-item-modal"
      data-testid="delete-item-modal"
      variant="danger"
      :title="deleteConfirmTitle"
      :action-fn="() => deleteFn(forceHardDelete)"
      :action-text="__('Delete')"
      @close="showDeleteModal = false"
    >
      <gl-sprintf :message="deleteConfirmMessage">
        <template #name>
          <strong class="gl-wrap-anywhere">{{ item.name }}</strong>
        </template>
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
      <div v-if="canHardDelete">
        <label for="delete-method" class="gl-mb-0 gl-mt-4 gl-block">
          {{ s__('AICatalog|Deletion method') }}
        </label>
        <p class="gl-mb-3 gl-text-subtle">
          <gl-sprintf
            :message="s__('AICatalog|Choose whether to delete or hide this %{itemType}.')"
          >
            <template #itemType>{{ itemTypeLabel }}</template>
          </gl-sprintf>
        </p>
        <gl-form-radio-group id="delete-method" v-model="forceHardDelete">
          <gl-form-radio v-for="option in deleteOptions" :key="option.text" :value="option.value">
            {{ option.text }}
            <template #help>
              {{ option.help }}
            </template>
          </gl-form-radio>
        </gl-form-radio-group>
      </div>
    </confirm-action-modal>
    <confirm-action-modal
      v-if="showDisableModal"
      modal-id="disable-item-modal"
      variant="danger"
      :title="disableConfirmTitle"
      :action-fn="disableFn"
      :action-text="__('Disable')"
      @close="showDisableModal = false"
    >
      <gl-sprintf :message="disableConfirmMessage">
        <template #name>
          <strong class="gl-wrap-anywhere">{{ item.name }}</strong>
        </template>
      </gl-sprintf>
    </confirm-action-modal>
    <component
      :is="enableModalComponent"
      v-if="canUse"
      modal-id="enable-item-modal"
      :item="item"
      :show-add-to-group="showAddToGroup"
      v-bind="enableModalProps"
      @submit="$emit('add-to-target', $event)"
    />
    <ai-catalog-item-report-modal
      v-if="canReport"
      :item="item"
      @submit="$emit('report-item', $event)"
    />
  </div>
</template>
