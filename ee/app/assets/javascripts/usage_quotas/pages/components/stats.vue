<script>
import { GlLink, GlTooltipDirective } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import { s__ } from '~/locale';

export default {
  name: 'PagesDeploymentsStats',
  components: { GlLink, SectionedPercentageBar, HelpIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['fullPath', 'deploymentsLimit', 'deploymentsCount', 'deploymentsByProject'],
  static: {
    helpLink: `${DOCS_URL_IN_EE_DIR}/user/project/pages/#limits`,
  },
  i18n: {
    description: s__('PagesUsageQuota|Active parallel deployments'),
    remainingDeploymentsLabel: s__('PagesUsageQuota|Remaining deployments'),
    helpText: s__('PagesUsageQuota|Learn about limits for Pages deployments'),
  },
  props: {
    title: {
      type: String,
      required: true,
    },
  },
  computed: {
    remainingDeployments() {
      return this.deploymentsLimit - this.deploymentsCount;
    },
    usedDeploymentsSection() {
      return this.deploymentsByProject
        .filter((project) => project.count > 0)
        .map((project, index) => ({
          id: index,
          label: project.name,
          value: project.count,
          formattedValue: String(project.count),
        }));
    },
    sections() {
      return [
        ...this.usedDeploymentsSection,
        {
          id: 'free',
          value: this.remainingDeployments,
          label: this.$options.i18n.remainingDeploymentsLabel,
          formattedValue: this.remainingDeployments,
          color: 'var(--gray-50)',
          hideLabel: true,
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-flex gl-justify-between gl-align-top">
      <div class="gl-mb-6 gl-grow">
        <h2 class="gl-heading-2 gl-mb-2">{{ title }}</h2>
        <p class="gl-mb-0 gl-max-w-6/8">
          {{ $options.i18n.description }}
          <gl-link
            v-gl-tooltip
            :href="$options.static.helpLink"
            target="_blank"
            class="gl-ml-2 gl-text-secondary"
            :title="$options.i18n.helpText"
            :aria-label="$options.i18n.helpText"
          >
            <help-icon />
          </gl-link>
        </p>
      </div>
      <p
        class="gl-mb-3 gl-grow-0 gl-text-nowrap gl-text-size-h-display gl-font-bold"
        data-testid="count"
      >
        {{ deploymentsCount }} / {{ deploymentsLimit }}
      </p>
    </div>
    <sectioned-percentage-bar :sections="sections" />
  </div>
</template>
