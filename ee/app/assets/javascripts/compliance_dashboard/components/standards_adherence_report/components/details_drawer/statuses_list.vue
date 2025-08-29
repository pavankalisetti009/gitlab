<script>
import { GlBadge, GlButton, GlIcon, GlLoadingIcon, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import complianceRequirementsControls from '../../graphql/queries/compliance_requirements_controls.query.graphql';
import DrawerAccordion from '../../../shared/drawer_accordion.vue';
import { EXTERNAL_CONTROL_LABEL } from '../../../../constants';
import { statusesInfo } from './statuses_info';

export default {
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlLoadingIcon,
    GlSprintf,
    GlLink,

    DrawerAccordion,
  },
  props: {
    controlStatuses: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      complianceRequirementsControls: [],
    };
  },
  apollo: {
    complianceRequirementsControls: {
      query: complianceRequirementsControls,
      update(data) {
        return data.complianceRequirementControls.controlExpressions;
      },
    },
  },
  computed: {
    sortedControlStatuses() {
      const STATUSES_ORDER = ['FAIL', 'PENDING', 'PASS'];
      return [...this.controlStatuses].sort((a, b) => {
        const aIndex = STATUSES_ORDER.indexOf(a.status);
        const bIndex = STATUSES_ORDER.indexOf(b.status);
        return aIndex - bIndex;
      });
    },
  },
  methods: {
    getControlName(controlStatus) {
      if (controlStatus.complianceRequirementsControl.controlType === 'external') {
        return controlStatus.complianceRequirementsControl.externalControlName;
      }
      return (
        this.complianceRequirementsControls.find(
          (c) => c.id === controlStatus.complianceRequirementsControl.name,
        )?.name ?? controlStatus.complianceRequirementsControl.name
      );
    },
    getStatusInfo(status) {
      const DEFAULT_VALUE = {
        description: '',
        fixes: [],
      };

      if (status.controlType === 'external') {
        return DEFAULT_VALUE;
      }

      return statusesInfo[status.name] || DEFAULT_VALUE;
    },
    getProjectSettingsUrl(controlStatus) {
      const statusInfo = this.getStatusInfo(controlStatus.complianceRequirementsControl);
      if (!statusInfo.projectSettingsPath || !this.project?.webUrl) {
        return null;
      }
      return `${this.project.webUrl}${statusInfo.projectSettingsPath}`;
    },
  },
  i18n: {
    EXTERNAL_CONTROL_LABEL,
    projectSettingsButton: s__('ComplianceStandardsAdherence|Go to project settings'),
  },
};
</script>
<template>
  <gl-loading-icon v-if="$apollo.queries.complianceRequirementsControls.loading" class="gl-mt-5" />
  <drawer-accordion v-else :items="sortedControlStatuses" class="!gl-p-0">
    <template #header="{ item: controlStatus }">
      <h4 class="gl-heading-4 gl-mb-3">
        <template v-if="controlStatus.complianceRequirementsControl.controlType === 'internal'">
          {{ getControlName(controlStatus) }}
        </template>
        <template v-if="controlStatus.complianceRequirementsControl.controlType === 'external'">
          {{ getControlName(controlStatus) }}
          <gl-badge>{{ $options.i18n.EXTERNAL_CONTROL_LABEL }}</gl-badge>
        </template>
      </h4>
      <div class="gl-flex gl-flex-row gl-gap-3">
        <span v-if="controlStatus.status === 'FAIL'" class="gl-text-status-danger">
          <gl-icon name="status_failed" class="gl-mr-2" />{{
            s__('ComplianceStandardsAdherence|Failed')
          }}
          <span
            v-if="getStatusInfo(controlStatus.complianceRequirementsControl).fixes.length"
            class="gl-text-status-neutral"
          >
            {{ s__('ComplianceStandardsAdherence|Fix available') }}
          </span>
        </span>
        <span v-if="controlStatus.status === 'PENDING'" class="gl-text-status-neutral">
          <gl-loading-icon inline class="gl-mr-2" />{{
            s__('ComplianceStandardsAdherence|Pending')
          }}
        </span>
        <span v-if="controlStatus.status === 'PASS'" class="gl-text-status-success">
          <gl-icon name="status_success" class="gl-mr-2" />{{
            s__('ComplianceStandardsAdherence|Passed')
          }}
        </span>
      </div>
    </template>
    <template #default="{ item: controlStatus }">
      <p v-if="controlStatus.complianceRequirementsControl.controlType === 'external'">
        <gl-sprintf
          :message="s__('ComplianceStandardsAdherence|This is an external control for %{link}')"
        >
          <template #link>
            <gl-link
              :href="controlStatus.complianceRequirementsControl.externalUrl"
              target="_blank"
            >
              {{ controlStatus.complianceRequirementsControl.externalUrl }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
      <p v-else>{{ getStatusInfo(controlStatus.complianceRequirementsControl).description }}</p>

      <template v-if="getStatusInfo(controlStatus.complianceRequirementsControl).fixes.length">
        <h4 class="gl-heading-4">
          {{ s__('ComplianceStandardsAdherence|How to fix') }}
        </h4>
        <div
          v-for="(fix, index) in getStatusInfo(controlStatus.complianceRequirementsControl).fixes"
          :key="index"
          class="gl-mb-5"
        >
          <h5 class="gl-heading-5 gl-flex gl-flex-row gl-items-center gl-gap-2">
            {{ fix.title }}
            <gl-badge v-if="fix.ultimate" variant="tier" icon="license" icon-size="md">{{
              __('Ultimate')
            }}</gl-badge>
          </h5>
          <p :key="`description-${index}`">{{ fix.description }}</p>
          <div class="gl-display-flex gl-flex-wrap gl-gap-3">
            <gl-button
              :key="`button-${index}`"
              category="secondary"
              variant="confirm"
              size="small"
              :href="fix.link"
              target="_blank"
              icon="external-link"
              class="gl-flex-shrink-0"
              data-testid="documentation-button"
            >
              {{ fix.linkTitle }}
            </gl-button>
            <gl-button
              v-if="getStatusInfo(controlStatus.complianceRequirementsControl).projectSettingsPath"
              :key="`settings-button-${index}`"
              category="secondary"
              variant="default"
              size="small"
              :href="getProjectSettingsUrl(controlStatus)"
              icon="settings"
              class="gl-flex-shrink-0"
              data-testid="settings-button"
            >
              {{ $options.i18n.projectSettingsButton }}
            </gl-button>
          </div>
        </div>
      </template>
    </template>
  </drawer-accordion>
</template>
