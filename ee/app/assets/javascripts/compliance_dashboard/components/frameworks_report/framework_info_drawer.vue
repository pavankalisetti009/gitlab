<script>
import { GlDrawer, GlBadge, GlButton, GlLabel, GlLink, GlSprintf, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isTopLevelGroup } from '../../utils';

export default {
  name: 'FrameworkInfoDrawer',
  components: {
    GlBadge,
    GlDrawer,
    GlButton,
    GlLabel,
    GlLink,
    GlSprintf,
    GlPopover,
  },
  inject: ['groupSecurityPoliciesPath'],
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    framework: {
      type: Object,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  emits: ['edit', 'close'],
  computed: {
    editDisabled() {
      return !isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    showDrawer() {
      return Boolean(this.framework);
    },
    getContentWrapperHeight() {
      return getContentWrapperHeight();
    },
    frameworkSettingsPath() {
      return this.framework.webUrl;
    },
    defaultFramework() {
      return Boolean(this.framework.default);
    },
    associatedProjectsTitle() {
      return `${this.$options.i18n.associatedProjects} (${this.framework.projects.nodes.length})`;
    },
    policies() {
      return [
        ...this.framework.scanExecutionPolicies.nodes,
        ...this.framework.scanResultPolicies.nodes,
      ];
    },
    policiesTitle() {
      return `${this.$options.i18n.policies} (${this.policies.length})`;
    },
    normalisedFrameworkId() {
      return getIdFromGraphQLId(this.framework.id);
    },
  },
  methods: {
    getPolicyEditUrl(policy) {
      const { urlParameter } = Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        // eslint-disable-next-line no-underscore-dangle
        (o) => o.typeName === policy.__typename,
      );

      return `${this.groupSecurityPoliciesPath}/${policy.name}/edit?type=${urlParameter}`;
    },
    copyIdToClipboard() {
      navigator?.clipboard?.writeText(this.normalisedFrameworkId);
      this.$toast.show(this.$options.i18n.copyIdToastText);
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    defaultFramework: s__('ComplianceFrameworksReport|Default'),
    editFramework: s__('ComplianceFrameworksReport|Edit framework'),
    editFrameworkButtonMessage: s__(
      'ComplianceFrameworks|The compliance framework must be edited in top-level group %{linkStart}namespace%{linkEnd}',
    ),
    frameworkIdTitle: s__('ComplianceFrameworksReport|Compliance framework ID'),
    frameworkIdButtonText: s__('ComplianceFrameworksReport|Copy ID'),
    copyIdToastText: s__('ComplianceFrameworksReport|Framework ID copied to clipboard.'),
    frameworkDescription: s__('ComplianceFrameworksReport|Description'),
    associatedProjects: s__('ComplianceFrameworksReport|Associated Projects'),
    policies: s__('ComplianceFrameworksReport|Policies'),
  },
};
</script>

<template>
  <gl-drawer
    :open="showDrawer"
    :header-height="getContentWrapperHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template v-if="framework" #title>
      <div class="gl-display-flex gl-flex-wrap gl-align-items-center gl-gap-4">
        <h2 class="gl-my-0" data-testid="framework-name">
          {{ framework.name }}
        </h2>
        <gl-label
          v-if="defaultFramework"
          :background-color="framework.color"
          :title="$options.i18n.defaultFramework"
        />
      </div>
    </template>

    <template v-if="framework" #header>
      <gl-popover
        v-if="editDisabled"
        target="framework-info-drawer-edit-button"
        placement="left"
        boundary="viewport"
      >
        <gl-sprintf :message="$options.i18n.editFrameworkButtonMessage">
          <template #link>
            <gl-link :href="rootAncestor.complianceCenterPath">
              {{ rootAncestor.name }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-popover>
      <span id="framework-info-drawer-edit-button">
        <gl-button
          :disabled="editDisabled"
          class="gl-mt-5"
          category="primary"
          variant="confirm"
          @click="$emit('edit', framework)"
        >
          {{ $options.i18n.editFramework }}
        </gl-button>
      </span>
    </template>

    <template v-if="framework" #default>
      <div>
        <div class="gl-mb-5" data-testid="sidebar-id">
          <div class="gl-flex gl-align-items-center">
            <h3 class="gl-mt-0" data-testid="sidebar-id-title">
              {{ $options.i18n.frameworkIdTitle }}
            </h3>
          </div>
          <div class="gl-flex">
            <span data-testid="framework-id">{{ normalisedFrameworkId }}</span>
            <gl-button
              class="gl-ml-3"
              variant="link"
              data-testid="copy-id-button"
              @click="copyIdToClipboard"
              >{{ $options.i18n.frameworkIdButtonText }}</gl-button
            >
          </div>
        </div>
        <div class="gl-border-t">
          <h3 data-testid="sidebar-description-title" class="gl-mt-5">
            {{ $options.i18n.frameworkDescription }}
          </h3>
          <span data-testid="sidebar-description">
            {{ framework.description }}
          </span>
        </div>
        <div class="gl-my-5 gl-border-t" data-testid="sidebar-projects">
          <h3 data-testid="sidebar-projects-title" class="gl-mt-5">
            {{ associatedProjectsTitle }}
          </h3>
          <ul class="gl-pl-6">
            <li
              v-for="associatedProject in framework.projects.nodes"
              :key="associatedProject.id"
              class="gl-mt-1"
            >
              <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link>
            </li>
          </ul>
        </div>
        <div class="gl-mb-5 gl-border-t" data-testid="sidebar-policies">
          <h3 data-testid="sidebar-policies-title" class="gl-mt-5">
            {{ policiesTitle }}
          </h3>
          <div v-if="policies.length">
            <div
              v-for="(policy, idx) in policies"
              :key="idx"
              class="gl-m-4 gl-display-flex gl-flex-direction-column gl-align-items-flex-start"
            >
              <gl-link :href="getPolicyEditUrl(policy)">{{ policy.name }}</gl-link>
              <gl-badge v-if="policy.source.namespace.fullPath !== groupPath" variant="muted">
                {{ policy.source.namespace.name }}
              </gl-badge>
            </div>
          </div>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
