<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { convertToTitleCase } from '~/lib/utils/text_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import groupCustomRoles from 'ee/security_orchestration/graphql/queries/group_custom_roles.query.graphql';
import projectCustomRoles from 'ee/security_orchestration/graphql/queries/project_custom_roles.query.graphql';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  i18n: {
    standardRoleText: s__('SecurityOrchestration|Standard roles'),
    customRoleText: s__('SecurityOrchestration|Custom roles'),
    dropdownSubheader: s__('SecurityOrchestration|Choose specific role'),
  },
  components: {
    GlCollapsibleListbox,
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
          data[this.namespaceType]?.memberRoles?.nodes.map(({ id, name }) => ({
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
    existingApprovers: {
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
    hasCustomRoles() {
      return this.customRoles.length && this.glFeatures.securityPolicyCustomRoles;
    },
    hasValidRoles() {
      return this.existingApprovers.every(this.isRoleValid);
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
      const validExistingApprovers = this.existingApprovers.filter(this.isRoleValid);
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
    isRoleValid(role) {
      return (
        this.roleApproverTypes.includes(role) || this.customRoles.map((r) => r.value).includes(role)
      );
    },
    handleSelectedRoles(selectedRoles) {
      this.$emit('updateSelectedApprovers', selectedRoles);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="items"
    block
    is-check-centered
    multiple
    :toggle-class="[{ '!gl-shadow-inner-1-red-500': !state }]"
    :selected="existingApprovers"
    :toggle-text="toggleText"
    @select="handleSelectedRoles"
  />
</template>
