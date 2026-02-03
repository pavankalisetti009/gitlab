<script>
import { uniqueId } from 'lodash';
import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlFormGroup, GlModal } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import {
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
} from 'ee/ai/catalog/constants';
import GroupItemConsumerDropdown from './group_item_consumer_dropdown.vue';
import AddAgentWarning from './add_agent_warning.vue';
import AddFlowWarning from './add_flow_warning.vue';
import AddThirdPartyFlowWarning from './add_third_party_flow_warning.vue';

export default {
  name: 'AddProjectItemConsumerModal',
  components: {
    GlForm,
    GlFormCheckbox,
    GlFormCheckboxGroup,
    GlFormGroup,
    GlModal,
    ErrorsAlert,
    GroupItemConsumerDropdown,
    AddAgentWarning,
    AddFlowWarning,
    AddThirdPartyFlowWarning,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    itemTypes: {
      type: Array,
      required: true,
    },
    modalId: {
      type: String,
      required: true,
    },
    modalTexts: {
      type: Object,
      required: true,
    },
    item: {
      type: Object,
      required: false,
      default: () => {},
    },
    showAddToGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    useRootGroupFlows: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      errors: [],
      isDirty: false,
      selectedGroupItemConsumer: {},
      triggerTypes: [],
      groupId: this.item?.project?.rootGroup?.id || null,
      projectId: this.item?.project?.id || null,
    };
  },
  computed: {
    availableFlowTriggerTypes() {
      return FLOW_TRIGGER_TYPES.filter(
        (type) => this.glFeatures.aiFlowTriggerPipelineHooks || type.value !== 'pipeline_hooks',
      );
    },
    formId() {
      return uniqueId('add-project-item-consumer-form-');
    },
    modal() {
      return {
        actionPrimary: {
          text: __('Enable'),
          attributes: {
            variant: 'confirm',
            type: 'submit',
            form: this.formId,
          },
        },
        actionCancel: {
          text: __('Cancel'),
        },
      };
    },
    modalTitle() {
      if (this.itemTypeLabel) {
        return sprintf(s__('AICatalog|Enable %{itemType} in your project'), {
          itemType: this.itemTypeLabel,
        });
      }

      return this.modalTexts.title;
    },
    isGroupItemConsumerValid() {
      return (
        !this.isDirty ||
        this.selectedGroupItemConsumer?.id !== undefined ||
        this.item?.id !== undefined
      );
    },
    isFoundationalFlow() {
      return (
        this.selectedItemType === AI_CATALOG_TYPE_FLOW &&
        (this.selectedGroupItemConsumer.item?.foundational || this.item?.foundational)
      );
    },
    showTriggers() {
      if (this.isFoundationalFlow) {
        return false;
      }
      return [AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(
        this.selectedItemType,
      );
    },
    triggersLabelDescription() {
      return sprintf(
        s__(
          'AICatalog|Choose what events in this project trigger the %{itemType}. You can change this later.',
        ),
        { itemType: this.itemTypeLabel },
      );
    },
    selectedItemType() {
      return this.selectedGroupItemConsumer.item?.itemType || this.item?.itemType;
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.selectedItemType] || '';
    },
    isTriggersValid() {
      return !this.showTriggers || !this.isDirty || this.triggerTypes.length > 0;
    },
    targetType() {
      return this.showAddToGroup
        ? AI_CATALOG_CONSUMER_TYPE_GROUP
        : AI_CATALOG_CONSUMER_TYPE_PROJECT;
    },
    isTargetTypeGroup() {
      return this.targetType === AI_CATALOG_CONSUMER_TYPE_GROUP;
    },
    warningComponent() {
      const warningComponentMap = {
        [AI_CATALOG_TYPE_AGENT]: AddAgentWarning,
        [AI_CATALOG_TYPE_FLOW]: AddFlowWarning,
        [AI_CATALOG_TYPE_THIRD_PARTY_FLOW]: AddThirdPartyFlowWarning,
      };
      return warningComponentMap[this.selectedItemType];
    },
  },
  mounted() {
    this.triggerTypes = this.availableFlowTriggerTypes.map((type) => type.value);
  },
  methods: {
    resetForm() {
      this.selectedGroupItemConsumer = {};
      this.triggerTypes = FLOW_TRIGGER_TYPES.map((type) => type.value);
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isGroupItemConsumerValid || !this.isTriggersValid) {
        return;
      }

      const target = this.isTargetTypeGroup
        ? { groupId: this.groupId }
        : { projectId: this.projectId };
      this.$emit('submit', {
        itemId: this.selectedGroupItemConsumer.item?.id,
        itemName: this.selectedGroupItemConsumer.item?.name,
        parentItemConsumerId: this.selectedGroupItemConsumer.id,
        target,
        ...(this.showTriggers ? { triggerTypes: this.triggerTypes } : {}),
      });
      this.$refs.modal.hide();
    },
    onHidden() {
      this.errors = [];
      this.isDirty = false;
      this.resetForm();
    },
    onGroupItemConsumerSelect(itemConsumer) {
      this.selectedGroupItemConsumer = itemConsumer;
    },
    onError() {
      this.errors = [this.modalTexts.error];
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
    :title="modalTitle"
    :action-primary="modal.actionPrimary"
    :action-cancel="modal.actionCancel"
    @primary.prevent
    @hidden="onHidden"
  >
    <errors-alert class="gl-mt-5" :errors="errors" @dismiss="errors = []" />
    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <dl v-if="item">
        <dt class="gl-mb-2 gl-font-bold">
          {{ modalTexts.label }}
        </dt>
        <dd class="gl-break-all">{{ item.name }}</dd>
      </dl>
      <gl-form-group
        v-else
        :label="modalTexts.label"
        :label-description="modalTexts.labelDescription"
        label-for="group-item-consumer-dropdown"
        :state="isGroupItemConsumerValid"
        :invalid-feedback="modalTexts.invalidFeedback"
      >
        <group-item-consumer-dropdown
          id="group-item-consumer-dropdown"
          :value="selectedGroupItemConsumer.id"
          :dropdown-texts="modalTexts.dropdownTexts"
          :is-valid="isGroupItemConsumerValid"
          :item-types="itemTypes"
          :use-root-group-flows="useRootGroupFlows"
          @input="onGroupItemConsumerSelect"
          @error="onError"
        />
      </gl-form-group>
      <gl-form-group
        v-if="showTriggers"
        :label="s__('AICatalog|Add triggers')"
        :label-description="triggersLabelDescription"
        label-for="flow-triggers"
        :state="isTriggersValid"
        :invalid-feedback="s__('AICatalog|Select at least one trigger.')"
      >
        <gl-form-checkbox-group id="flow-triggers" v-model="triggerTypes">
          <gl-form-checkbox
            v-for="triggerType in availableFlowTriggerTypes"
            :key="triggerType.value"
            :value="triggerType.value"
          >
            {{ triggerType.text }}
            <template #help>{{ triggerType.createHelp(itemTypeLabel) }}</template>
          </gl-form-checkbox>
        </gl-form-checkbox-group>
      </gl-form-group>
    </gl-form>
    <component :is="warningComponent" v-if="warningComponent" />
  </gl-modal>
</template>
