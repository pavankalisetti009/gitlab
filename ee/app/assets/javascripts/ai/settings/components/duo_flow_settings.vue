<script>
import {
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { duoFlowHelpPath } from '~/pages/projects/shared/permissions/constants';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { helpPagePath } from '~/helpers/help_page_helper';
import FoundationalFlowSelector from './foundational_flow_selector.vue';

export default {
  name: 'DuoFlowSettings',
  i18n: {
    sectionTitle: __('Flow execution'),
    checkboxLabel: s__('DuoAgentPlatform|Allow flow execution'),
    checkboxHelpTextGroup: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows in this group and its subgroups and projects. %{linkStart}What are flows%{linkEnd}?',
    ),
    checkboxHelpTextInstance: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows for the instance. %{linkStart}What are flows%{linkEnd}?',
    ),
    foundationalFlowsLabel: s__('DuoAgentPlatform|Allow foundational flows'),
    foundationalFlowsHelpTextGroup: s__(
      'AiPowered|Allow GitLab Duo agents to execute foundational flows in this group and its subgroups and projects.',
    ),
    foundationalFlowsHelpTextInstance: s__(
      'AiPowered|Allow GitLab Duo agents to execute foundational flows for the instance.',
    ),
    defaultImageRegistryLabel: s__('DuoAgentPlatform|Image registry'),
    defaultImageRegistryHelp: s__(
      'AiPowered|Container registry for foundational flow images. Leave blank to use registry.gitlab.com',
    ),
    defaultImageRegistryPlaceholder: s__('AiPowered|registry.gitlab.com'),
  },
  components: {
    CascadingLockIcon,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlLink,
    GlSprintf,
    FoundationalFlowSelector,
  },

  directives: {
    tooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'isGroupSettings',
    'isSaaS',
    'duoRemoteFlowsCascadingSettings',
    'duoFoundationalFlowsCascadingSettings',
  ],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    duoFoundationalFlowsAvailability: {
      type: Boolean,
      required: true,
    },
    selectedFoundationalFlowIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    duoWorkflowsDefaultImageRegistry: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      flowEnabled: this.duoRemoteFlowsAvailability,
      foundationalFlowsEnabled: this.duoFoundationalFlowsAvailability,
      localSelectedFlowIds: this.selectedFoundationalFlowIds,
      defaultImageRegistry: this.duoWorkflowsDefaultImageRegistry,
    };
  },
  computed: {
    description() {
      return this.isGroupSettings
        ? this.$options.i18n.checkboxHelpTextGroup
        : this.$options.i18n.checkboxHelpTextInstance;
    },
    foundationalFlowsDescription() {
      return this.isGroupSettings
        ? this.$options.i18n.foundationalFlowsHelpTextGroup
        : this.$options.i18n.foundationalFlowsHelpTextInstance;
    },
    showCascadingButton() {
      return (
        this.duoRemoteFlowsCascadingSettings?.lockedByAncestor ||
        this.duoRemoteFlowsCascadingSettings?.lockedByApplicationSetting
      );
    },
    showCascadingButtonFoundationalFlows() {
      return (
        this.duoFoundationalFlowsCascadingSettings?.lockedByAncestor ||
        this.duoFoundationalFlowsCascadingSettings?.lockedByApplicationSetting
      );
    },
    shouldShowImageRegistryInput() {
      return !this.isGroupSettings && !this.isSaaS && this.foundationalFlowsEnabled;
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.flowEnabled);
    },
    checkboxFoundationalFlowChanged() {
      this.$emit('change-foundational-flows', this.foundationalFlowsEnabled);

      if (!this.foundationalFlowsEnabled) {
        this.localSelectedFlowIds = [];
        this.$emit('change-selected-flow-ids', []);
      }
    },
    onFlowSelectionChanged(flowIds) {
      this.localSelectedFlowIds = flowIds;
      this.$emit('change-selected-flow-ids', flowIds);
    },
    onDefaultImageRegistryChanged() {
      this.$emit('change-default-image-registry', this.defaultImageRegistry);
    },
  },
  duoFlowHelpPath,
  duoFlowPrerequisitesHelpPath: helpPagePath('user/duo_agent_platform/flows/_index.md', {
    anchor: 'prerequisites',
  }),
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle">
      <gl-form-checkbox
        v-model="flowEnabled"
        data-testid="duo-flow-features-checkbox"
        :disabled="disabledCheckbox || showCascadingButton"
        @change="checkboxChanged"
      >
        <div class="gl-flex">
          <span id="duo-flow-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
          <span
            v-if="disabledCheckbox"
            v-tooltip="
              s__(
                'AiPowered|This setting requires GitLab Duo availability to be on or off by default.',
              )
            "
            class="gl-ml-2"
            :aria-label="s__('AiPowered|Lock tooltip icon')"
            data-testid="duo-flow-feature-checkbox-locked"
          >
            <gl-icon name="lock" />
          </span>
          <cascading-lock-icon
            v-if="showCascadingButton"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoRemoteFlowsCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoRemoteFlowsCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoRemoteFlowsCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          <gl-sprintf :message="description">
            <template #link="{ content }">
              <gl-link :href="$options.duoFlowHelpPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>
      <gl-form-checkbox
        v-model="foundationalFlowsEnabled"
        data-testid="duo-foundational-flows-features-checkbox"
        :disabled="disabledCheckbox || !flowEnabled || showCascadingButtonFoundationalFlows"
        @change="checkboxFoundationalFlowChanged"
      >
        <div class="gl-flex">
          <span id="duo-flow-checkbox-label">{{
            s__('DuoAgentPlatform|Allow foundational flows')
          }}</span>
          <span
            v-if="disabledCheckbox || !flowEnabled"
            v-tooltip="s__('AiPowered|This setting requires Allow flow execution to be on')"
            class="gl-ml-2"
            :aria-label="s__('AiPowered|Lock tooltip icon')"
            data-testid="duo-flow-feature-checkbox-locked"
          >
            <gl-icon name="lock" />
          </span>
          <cascading-lock-icon
            v-if="showCascadingButtonFoundationalFlows"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoFoundationalFlowsCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoFoundationalFlowsCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoFoundationalFlowsCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          {{ foundationalFlowsDescription }}
          {{ s__('AiPowered|Ensure members can be added to the group that contains the project.') }}
          <gl-link :href="$options.duoFlowPrerequisitesHelpPath">{{ __('Learn more') }}</gl-link>
        </template>
      </gl-form-checkbox>

      <foundational-flow-selector
        v-if="foundationalFlowsEnabled"
        v-model="localSelectedFlowIds"
        :disabled="disabledCheckbox || !flowEnabled || showCascadingButtonFoundationalFlows"
        @input="onFlowSelectionChanged"
      />

      <div v-if="shouldShowImageRegistryInput" class="gl-mt-5">
        <label for="duo-workflows-default-image-registry">
          {{ $options.i18n.defaultImageRegistryLabel }}
        </label>
        <gl-form-input
          id="duo-workflows-default-image-registry"
          v-model="defaultImageRegistry"
          name="application_setting[duo_workflows_default_image_registry]"
          type="text"
          :placeholder="$options.i18n.defaultImageRegistryPlaceholder"
          :disabled="disabledCheckbox || !flowEnabled"
          data-testid="duo-workflows-default-image-registry-input"
          @input="onDefaultImageRegistryChanged"
        />
        <p class="gl-mb-0 gl-mt-2 gl-text-secondary">
          {{ $options.i18n.defaultImageRegistryHelp }}
        </p>
      </div>
    </gl-form-group>
  </div>
</template>
