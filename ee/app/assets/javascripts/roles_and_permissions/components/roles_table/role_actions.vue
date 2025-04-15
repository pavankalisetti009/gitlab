<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlPopover,
  GlSprintf,
  GlTooltip,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isCustomRole, isAdminRole } from '../../utils';

export default {
  i18n: {
    accessLevelText: s__('MemberRole|Access level: %{id}'),
    roleIdText: s__('MemberRole|Role ID: %{id}'),
    viewDetailsText: __('View details'),
    editRoleText: s__('MemberRole|Edit role'),
    deleteRoleText: s__('MemberRole|Delete role'),
    accessLevelCopied: s__('MemberRole|Access level copied to clipboard'),
    roleIdCopied: s__('MemberRole|Role ID copied to clipboard'),
    deleteDisabledTooltip: s__(
      "MemberRole|You can't delete this custom role until you remove it from all group members.",
    ),
    deletePopoverTitle: s__('MemberRole|Security policy dependency'),
    deletePopoverText: s__(
      "MemberRole|You can't delete this custom role until you remove it from all security policies:",
    ),
  },
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlLink,
    GlPopover,
    GlSprintf,
    GlTooltip,
  },
  props: {
    role: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isCustomOrAdminRole() {
      return isCustomRole(this.role) || isAdminRole(this.role);
    },
    hasAssignedUsers() {
      return this.role.usersCount > 0;
    },
    roleId() {
      return this.isCustomOrAdminRole ? getIdFromGraphQLId(this.role.id) : this.role.accessLevel;
    },
    hasDependentSecurityPolicies() {
      return this.role.dependentSecurityPolicies?.length > 0;
    },
    idText() {
      const { roleIdText, accessLevelText } = this.$options.i18n;

      return this.isCustomOrAdminRole ? roleIdText : accessLevelText;
    },
    viewDetailsItem() {
      return { text: this.$options.i18n.viewDetailsText, href: this.role.detailsPath };
    },
    editRoleItem() {
      return { text: this.$options.i18n.editRoleText, href: this.role.editPath };
    },
    deleteActionId() {
      return `delete-role-action-${this.roleId}`;
    },
    deleteRoleItem() {
      return {
        text: this.$options.i18n.deleteRoleText,
        variant: this.hasAssignedUsers ? null : 'danger',
        extraAttrs: {
          disabled: this.hasAssignedUsers || this.hasDependentSecurityPolicies,
        },
      };
    },
    deleteTooltip() {
      return !this.hasDependentSecurityPolicies && this.hasAssignedUsers
        ? this.$options.i18n.deleteDisabledTooltip
        : '';
    },
  },
  methods: {
    showCopiedToClipboardToast() {
      const { roleIdCopied, accessLevelCopied } = this.$options.i18n;
      const toastMessage = this.isCustomOrAdminRole ? roleIdCopied : accessLevelCopied;
      this.$toast.show(toastMessage);
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown category="tertiary" icon="ellipsis_v" placement="bottom-end" no-caret>
    <gl-disclosure-dropdown-item
      :data-clipboard-text="roleId"
      data-testid="role-id-item"
      @action="showCopiedToClipboardToast"
    >
      <template #list-item>
        <gl-icon name="copy-to-clipboard" class="gl-mr-2" variant="subtle" />
        <gl-sprintf :message="idText">
          <template #id>{{ roleId }}</template>
        </gl-sprintf>
      </template>
    </gl-disclosure-dropdown-item>

    <gl-disclosure-dropdown-item data-testid="view-details-item" :item="viewDetailsItem" />

    <template v-if="isCustomOrAdminRole">
      <gl-disclosure-dropdown-item data-testid="edit-role-item" :item="editRoleItem" />
      <gl-disclosure-dropdown-item
        :id="deleteActionId"
        data-testid="delete-role-item"
        :item="deleteRoleItem"
        @action="$emit('delete')"
      />

      <gl-tooltip
        v-if="deleteTooltip"
        :target="deleteActionId"
        placement="left"
        boundary="viewport"
      >
        {{ deleteTooltip }}
      </gl-tooltip>

      <gl-popover
        v-if="hasDependentSecurityPolicies"
        :target="deleteActionId"
        placement="left"
        boundary="viewport"
        :title="$options.i18n.deletePopoverTitle"
        show-close-button
      >
        {{ $options.i18n.deletePopoverText }}
        <ul class="gl-pl-5">
          <li v-for="policy in role.dependentSecurityPolicies" :key="policy.name">
            <gl-link :href="policy.editPath" target="_blank">
              {{ policy.name }}
            </gl-link>
          </li>
        </ul>
      </gl-popover>
    </template>
  </gl-disclosure-dropdown>
</template>
