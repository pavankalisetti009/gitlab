<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
  GlIcon,
  GlSprintf,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  i18n: {
    accessLevelText: s__('MemberRole|Access level: %{id}'),
    roleIdText: s__('MemberRole|Role ID: %{id}'),
    viewDetailsText: __('View details'),
    editRoleText: s__('MemberRole|Edit role'),
    deleteRoleText: s__('MemberRole|Delete role'),
    accessLevelCopiedToClipboard: s__('MemberRole|Access level copied to clipboard'),
    idCopiedToClipboard: s__('MemberRole|Role ID copied to clipboard'),
    deleteDisabledTooltip: s__(
      'MemberRole|To delete custom role, remove role from all group members.',
    ),
  },
  components: { GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon, GlSprintf },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    role: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isCustomRole() {
      return Boolean(this.role.id);
    },
    hasAssignedUsers() {
      return this.role.membersCount > 0;
    },
    roleId() {
      return this.isCustomRole ? getIdFromGraphQLId(this.role.id) : this.role.accessLevel;
    },
    idText() {
      const { roleIdText, accessLevelText } = this.$options.i18n;

      return this.isCustomRole ? roleIdText : accessLevelText;
    },
    viewDetailsItem() {
      return { text: this.$options.i18n.viewDetailsText, href: this.role.detailsPath };
    },
    editRoleItem() {
      return { text: this.$options.i18n.editRoleText, href: this.role.editPath };
    },
    deleteRoleItem() {
      return {
        text: this.$options.i18n.deleteRoleText,
        action: () => this.$emit('delete'),
        extraAttrs: {
          disabled: this.hasAssignedUsers,
          class: this.hasAssignedUsers ? '' : '!gl-text-red-500',
        },
      };
    },
    deleteTooltip() {
      return this.hasAssignedUsers ? this.$options.i18n.deleteDisabledTooltip : '';
    },
  },
  methods: {
    showCopiedToClipboardToast() {
      const { idCopiedToClipboard, accessLevelCopiedToClipboard } = this.$options.i18n;
      this.$toast.show(this.isCustomRole ? idCopiedToClipboard : accessLevelCopiedToClipboard);
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
        <gl-icon name="copy-to-clipboard" class="gl-mr-2 gl-text-gray-400" />
        <gl-sprintf :message="idText">
          <template #id>{{ roleId }}</template>
        </gl-sprintf>
      </template>
    </gl-disclosure-dropdown-item>

    <gl-disclosure-dropdown-item data-testid="view-details-item" :item="viewDetailsItem" />

    <template v-if="isCustomRole">
      <gl-disclosure-dropdown-item data-testid="edit-role-item" :item="editRoleItem" />
      <gl-disclosure-dropdown-item
        v-gl-tooltip.left.viewport.d0="deleteTooltip"
        data-testid="delete-role-item"
        :item="deleteRoleItem"
      />
    </template>
  </gl-disclosure-dropdown>
</template>
