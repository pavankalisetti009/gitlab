<script>
import { GlCollapsibleListbox, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { convertToTitleCase } from '~/lib/utils/text_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { ROLE_PERMISSION_TO_APPROVE_MRS } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import groupCustomRoles from 'ee/security_orchestration/graphql/queries/group_custom_roles.query.graphql';
import projectCustomRoles from 'ee/security_orchestration/graphql/queries/project_custom_roles.query.graphql';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  i18n: {
    standardRoleText: s__('SecurityOrchestration|Standard roles'),
    customRoleText: s__('SecurityOrchestration|Custom roles'),
    dropdownSubheader: s__('SecurityOrchestration|Choose specific role'),
    customRoleDisclaimer: s__(
      'SecurityOrchestration|Only custom roles with the permission to approve merge requests are shown',
    ),
  },
  components: {
    GlCollapsibleListbox,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['roleApproverTypes', 'namespacePath', 'namespaceType'],
  apollo: {
    customRoles: {
      query() {
        return isGroup(this.namespaceType) ? groupCustomRoles : projectCustomRoles;
      },
      variables() {
        return { fullPath: this.namespacePath };
      },
      update(data = {}) {
        return (
          data[this.namespaceType]?.memberRoles?.nodes
            .filter(({ enabledPermissions }) =>
              enabledPermissions?.edges.some(
                ({ node = {} }) => node.value === ROLE_PERMISSION_TO_APPROVE_MRS,
              ),
            )
            .map(({ id, name }) => ({
              text: name,
              value: getIdFromGraphQLId(id),
            })) || []
        );
      },
      skip() {
        return !this.glFeatures.securityPolicyCustomRoles;
      },
    },
  },
  props: {
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    state: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      customRoles: [],
    };
  },
  computed: {
    hasCustomRoleFeatureFlag() {
      return this.glFeatures.securityPolicyCustomRoles;
    },
    hasCustomRoles() {
      return this.customRoles.length && this.hasCustomRoleFeatureFlag;
    },
    hasValidRoles() {
      return this.$apollo.loading || this.selected.every(this.isRoleValid);
    },
    items() {
      const roles = [{ text: this.$options.i18n.standardRoleText, options: this.roles }];

      if (this.hasCustomRoles) {
        roles.push({ text: this.$options.i18n.customRoleText, options: this.customRoles });
      }

      return roles;
    },
    roles() {
      return this.roleApproverTypes.map((r) => ({ text: convertToTitleCase(r), value: r }));
    },
    toggleText() {
      const validExistingApprovers = this.selected.filter(this.isRoleValid);
      const allRoles = this.items.map(({ options }) => options).flat();

      return getSelectedOptionsText({
        options: allRoles,
        selected: validExistingApprovers,
        placeholder: this.$options.i18n.dropdownSubheader,
        maxOptionsShown: 2,
      });
    },
  },
  watch: {
    hasValidRoles(value) {
      if (!value) {
        this.$emit('error');
      }
    },
  },
  methods: {
    selectRoles(roles) {
      this.$emit('select-items', { role_approvers: roles });
    },
    isRoleValid(role) {
      return (
        this.roleApproverTypes.includes(role) ||
        this.customRoles.map(({ value }) => value).includes(role)
      );
    },
  },
};
</script>

<template>
  <div class="gl-flex">
    <gl-collapsible-listbox
      :items="items"
      block
      is-check-centered
      multiple
      :header-text="__('Roles')"
      :reset-button-label="__('Clear all')"
      :toggle-class="[{ '!gl-shadow-inner-1-red-500': !state }]"
      :selected="selected"
      :toggle-text="toggleText"
      @reset="selectRoles([])"
      @select="selectRoles"
    />
    <gl-icon
      v-if="hasCustomRoleFeatureFlag"
      v-gl-tooltip
      name="information-o"
      class="gl-ml-3 gl-mt-3 gl-text-blue-500"
      :title="$options.i18n.customRoleDisclaimer"
    />
  </div>
</template>
