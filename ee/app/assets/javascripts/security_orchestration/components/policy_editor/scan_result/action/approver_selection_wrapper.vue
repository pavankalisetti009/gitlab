<script>
import {
  GlButton,
  GlForm,
  GlFormInput,
  GlCollapsibleListbox,
  GlSprintf,
  GlBadge,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import SectionLayout from '../../section_layout.vue';
import {
  ADD_APPROVER_LABEL,
  APPROVER_TYPE_LIST_ITEMS,
  DEFAULT_APPROVER_DROPDOWN_TEXT,
  getDefaultHumanizedTemplate,
  MULTIPLE_APPROVER_TYPES_HUMANIZED_TEMPLATE,
} from '../lib/actions';
import GroupSelect from './group_select.vue';
import RoleSelect from './role_select.vue';
import UserSelect from './user_select.vue';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    SectionLayout,
    GlBadge,
    GlButton,
    GlForm,
    GlFormInput,
    GlCollapsibleListbox,
    GlSprintf,
    GroupSelect,
    RoleSelect,
    UserSelect,
  },
  inject: ['namespaceId'],
  props: {
    approverIndex: {
      type: Number,
      required: true,
    },
    availableTypes: {
      type: Array,
      required: true,
    },
    approvalsRequired: {
      type: Number,
      required: true,
    },
    errors: {
      type: Array,
      required: false,
      default: () => [],
    },
    existingApprovers: {
      type: Object,
      required: true,
    },
    numOfApproverTypes: {
      type: Number,
      required: true,
    },
    approverType: {
      type: String,
      required: false,
      default: '',
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    approverTypeToggleText() {
      return this.approverType ? this.selected : DEFAULT_APPROVER_DROPDOWN_TEXT;
    },
    approverComponent() {
      switch (this.approverType) {
        case GROUP_TYPE:
          return GroupSelect;
        case ROLE_TYPE:
          return RoleSelect;
        case USER_TYPE:
        default:
          return UserSelect;
      }
    },
    hasAvailableTypes() {
      return Boolean(this.availableTypes.length);
    },
    humanizedTemplate() {
      return getDefaultHumanizedTemplate(this.approvalsRequired);
    },
    isApproversErrored() {
      return this.errors.some((error) => error.field === 'approvers_ids');
    },
    actionText() {
      return this.approverIndex === 0
        ? this.humanizedTemplate
        : MULTIPLE_APPROVER_TYPES_HUMANIZED_TEMPLATE;
    },
    selected() {
      return APPROVER_TYPE_LIST_ITEMS.find((v) => v.value === this.approverType)?.text;
    },
    showAddButton() {
      return (
        this.approverIndex + 1 < APPROVER_TYPE_LIST_ITEMS.length &&
        this.approverIndex + 1 === this.numOfApproverTypes
      );
    },
    listBoxItems() {
      return APPROVER_TYPE_LIST_ITEMS.map(({ value, text }) => ({
        value,
        text,
        disabled: this.availableTypes.find((item) => item.value === value) === undefined,
      }));
    },
  },
  methods: {
    addApproverType() {
      this.$emit('addApproverType');
    },
    approvalsRequiredChanged(value) {
      this.$emit('updateApprovalsRequired', parseInt(value, 10));
    },
    handleApproversUpdate({ updatedApprovers, type }) {
      const updatedExistingApprovers = { ...this.existingApprovers };
      updatedExistingApprovers[type] = updatedApprovers;
      this.$emit('updateApprovers', updatedExistingApprovers);
    },
    handleSelectedApproverType(newType) {
      const alreadySelected = this.availableTypes.find((v) => v.value === newType) === undefined;
      if (alreadySelected) return;

      this.$emit('updateApproverType', {
        newApproverType: newType,
        oldApproverType: this.approverType,
      });
    },
    handleRemoveApprover() {
      this.$emit('removeApproverType', this.approverType);
    },
  },
  i18n: {
    ADD_APPROVER_LABEL,
    disabledLabel: __('disabled'),
    disabledTitle: s__('SecurityOrchestration|You can select this option only once.'),
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-items-end gl-rounded-none gl-bg-white gl-py-0 gl-pr-0 md:gl-items-start"
    content-classes="gl-flex gl-w-full "
    :show-remove-button="showRemoveButton"
    @remove="handleRemoveApprover"
  >
    <template #content>
      <gl-form class="gl-w-full gl-items-center md:gl-flex" @submit.prevent>
        <div class="gl-mb-3 gl-flex gl-w-30 gl-items-center md:!gl-mb-0 md:gl-justify-end">
          <gl-sprintf :message="actionText">
            <template #require="{ content }">
              <strong>{{ content }}</strong>
            </template>

            <template #approvalsRequired>
              <gl-form-input
                :state="!isApproversErrored"
                :value="approvalsRequired"
                data-testid="approvals-required-input"
                type="number"
                class="gl-mx-3 !gl-w-11"
                :min="1"
                :max="100"
                @update="approvalsRequiredChanged"
              />
            </template>

            <template #approval="{ content }">
              <strong class="gl-mr-3">{{ content }}</strong>
            </template>
          </gl-sprintf>
        </div>

        <gl-collapsible-listbox
          class="gl-mx-0 gl-mb-3 gl-block md:gl-mb-0 md:gl-ml-3 md:gl-mr-3 md:gl-inline-flex"
          data-testid="available-types"
          :items="listBoxItems"
          :selected="selected"
          :toggle-text="approverTypeToggleText"
          :disabled="!hasAvailableTypes"
          @select="handleSelectedApproverType"
        >
          <template #list-item="{ item }">
            <span
              class="gl-flex"
              data-testid="list-item-content"
              :class="{ '!gl-cursor-default': item.disabled }"
            >
              <span
                :id="item.value"
                data-testid="list-item-text"
                class="gl-pr-3"
                :class="{ 'gl-text-gray-500': item.disabled }"
              >
                {{ item.text }}
              </span>
              <gl-badge
                v-if="item.disabled"
                v-gl-tooltip.right.viewport
                :title="$options.i18n.disabledTitle"
                class="gl-ml-auto"
                variant="neutral"
              >
                {{ $options.i18n.disabledLabel }}
              </gl-badge>
            </span>
          </template>
        </gl-collapsible-listbox>

        <template v-if="approverType">
          <component
            :is="approverComponent"
            :existing-approvers="existingApprovers[approverType]"
            :state="!isApproversErrored"
            class="security-policies-approver-max-width"
            @error="$emit('error')"
            @updateSelectedApprovers="
              handleApproversUpdate({
                updatedApprovers: $event,
                type: approverType,
              })
            "
          />
        </template>
      </gl-form>
      <gl-button
        v-if="showAddButton"
        class="gl-ml-2 gl-mt-4"
        variant="link"
        data-testid="add-approver"
        @click="addApproverType"
      >
        {{ $options.i18n.ADD_APPROVER_LABEL }}
      </gl-button>
    </template>
  </section-layout>
</template>
