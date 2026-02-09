<script>
import { GlCard } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import FeatureCard from './feature_card.vue';

export default {
  name: 'PremiumFeaturesSection',
  components: { FeatureCard, GlCard },
  data() {
    return {
      openPopoverId: null,
      premiumFeaturesCicd: [
        {
          id: 'merge-trains',
          text: s__('BillingPlans|Merge Trains'),
          description: s__(
            'BillingPlans|Automatically merge changes in sequence to prevent conflicts and keep your branch stable.',
          ),
          link: helpPagePath('ci/pipelines/merge_trains.md'),
        },
        {
          id: 'push-rules',
          text: s__('BillingPlans|Push Rules'),
          description: s__(
            'BillingPlans|Customizable pre-receive Git hooks that enforce commit content standards, message formats, branch naming rules, and file requirements.',
          ),
          link: helpPagePath('user/project/repository/push_rules.md'),
        },
        {
          id: 'merge-request-guardrails',
          text: s__('BillingPlans|Merge Request Guardrails'),
          description: s__(
            'BillingPlans|Customize approval workflows with rules defining who must review code before merging, including options to prevent self-approvals and require authentication.',
          ),
          link: helpPagePath('administration/merge_requests_approvals.md'),
        },
      ],
      premiumFeaturesPlatform: [
        {
          id: 'repository-pull-mirroring',
          text: s__('BillingPlans|Repository Pull Mirroring'),
          description: s__(
            'BillingPlans|Automatically sync branches, tags, and commits from an external repository.',
          ),
          link: helpPagePath('user/project/repository/mirror/pull.md'),
        },
        {
          id: 'epics',
          text: s__('BillingPlans|Epics'),
          description: s__(
            'BillingPlans|Track related issues to manage large initiatives and monitor progress toward long-term goals.',
          ),
          link: helpPagePath('user/group/epics/_index.md'),
        },
        {
          id: 'protected-environments',
          text: s__('BillingPlans|Protected Environments'),
          description: s__(
            'BillingPlans|Safeguard testing and production environments by restricting deployment access to authorized users only.',
          ),
          link: helpPagePath('ci/environments/protected_environments.md'),
        },
      ],
      premiumFeaturesVisibility: [
        {
          id: 'event-audits',
          text: s__('BillingPlans|Event Audits'),
          description: s__(
            'BillingPlans|Track critical security actions like permission changes and user modifications with comprehensive, permanent audit logs, providing detailed reports for compliance, incident response, and access reviews.',
          ),
          link: helpPagePath('user/compliance/audit_events.md', { anchor: 'group-audit-events' }),
        },
        {
          id: 'escalation-policies',
          text: s__('BillingPlans|Escalation Policies'),
          description: s__(
            'BillingPlans|Automatically notify the next responder when critical alerts are unacknowledged and ensure no incident is missed.',
          ),
          link: helpPagePath('operations/incident_management/escalation_policies.md'),
        },
        {
          id: 'compliance-center',
          text: s__('BillingPlans|Compliance Center'),
          description: s__(
            'BillingPlans|A central hub to manage standards adherence, violations reporting, and compliance frameworks.',
          ),
          link: helpPagePath('user/compliance/compliance_center/_index.md'),
        },
      ],
      premiumFeaturesScale: [
        {
          id: 'unlimited-licensed-users',
          text: s__('BillingPlans|Unlimited Licensed Users'),
          description: s__(
            'BillingPlans|Get unlimited user licenses, which includes guest user licenses, up from a maximum of 5 users on the Free plan.',
          ),
        },
        {
          id: 'priority-support',
          text: s__('BillingPlans|Priority Support'),
          description: s__('BillingPlans|Get support from GitLab with guaranteed response times.'),
        },
        {
          id: 'compute-minutes',
          text: s__('BillingPlans|10,000 Compute Minutes per Month'),
          description: s__(
            'BillingPlans|Get 10,000 compute minutes per month for your CI/CD pipelines, up from 400 on the Free plan.',
          ),
        },
      ],
      duoFeaturesCompanion: [
        {
          id: 'gitlab-duo-chat',
          text: s__('BillingPlans|GitLab Duo Chat'),
          description: s__(
            'BillingPlans|Chat that can be used throughout the GitLab platform, granting a much more fluid and efficient workflow experience.',
          ),
        },
        {
          id: 'flow',
          text: s__('BillingPlans|Flows'),
          description: s__(
            'BillingPlans|Combine one or more agents to solve complex problems. Use pre-built flows for common development tasks or create custom workflows with your own triggers and steps.',
          ),
        },
        {
          id: 'agents',
          text: s__('BillingPlans|Agents'),
          description: s__(
            "BillingPlans|AI-powered assistants that help you accomplish specific tasks and answer complex questions. Use pre-built agents for common workflows or create custom ones for your team's needs.",
          ),
        },
      ],
      duoFeaturesBuild: [
        {
          id: 'generate-tests',
          text: s__('BillingPlans|Generate tests and refactor efficiently'),
        },
        {
          id: 'explain-logic',
          text: s__('BillingPlans|Explain complex logic instantly'),
        },
        {
          id: 'automate-tasks',
          text: s__('BillingPlans|Automate repetitive development tasks'),
        },
      ],
      duoAgenticPlatformLink: helpPagePath('user/duo_agent_platform/_index.md'),
    };
  },
  methods: {
    handlePopoverToggle(featureId) {
      // If clicking the same popover, close it; otherwise open the new one
      this.openPopoverId = this.openPopoverId === featureId ? null : featureId;
    },
  },
};
</script>

<template>
  <gl-card body-class="p-5">
    <h2 class="gl-heading-2">
      {{ s__('BillingPlans|GitLab Premium features') }}
    </h2>

    <p class="gl-mb-6 gl-text-lg gl-font-normal gl-text-default">
      {{ s__('BillingPlans|Everything from Free, plus:') }}
    </p>
    <div class="gl-mb-8 gl-grid gl-grid-cols-1 gl-gap-6 md:gl-grid-cols-2">
      <feature-card
        :top-header="s__('BillingPlans|Enhanced CI/CD')"
        :bottom-header="s__('BillingPlans|Strengthen pipelines with advanced approvals workflows')"
        :items="premiumFeaturesCicd"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="premium-features-cicd"
      />

      <feature-card
        :top-header="s__('BillingPlans|Unified Platform')"
        :bottom-header="s__('BillingPlans|Consolidate your toolchain in one place')"
        :items="premiumFeaturesPlatform"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="premium-features-platform"
      />
      <feature-card
        :top-header="s__('BillingPlans|Visibility & Incident Response')"
        :bottom-header="s__('BillingPlans|Track critical actions and respond when issues arise')"
        :items="premiumFeaturesVisibility"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="premium-features-visibility"
      />
      <feature-card
        :top-header="s__('BillingPlans|Scale with Confidence')"
        :bottom-header="s__('BillingPlans|Built to grow with your team')"
        :items="premiumFeaturesScale"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="premium-features-scale"
      />
    </div>
    <h2 class="gl-heading-2">
      {{ s__('BillingPlans|Also featuring GitLab Duo Agent Platform') }}
    </h2>
    <p class="gl-mb-6 gl-text-lg gl-font-normal gl-text-default">
      {{ s__('BillingPlans|AI across the software development lifecycle.') }}
      <a :href="duoAgenticPlatformLink" class="gl-link" target="_blank" rel="noopener noreferrer">{{
        __('Learn more')
      }}</a
      >.
    </p>
    <div class="gl-grid gl-grid-cols-1 gl-gap-6 md:gl-grid-cols-2">
      <feature-card
        :top-header="s__('BillingPlans|Your AI companion throughout development')"
        :bottom-header="s__('BillingPlans|Access AI assistance wherever you\'re most productive')"
        :items="duoFeaturesCompanion"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="duo-features-companion"
      />
      <feature-card
        :top-header="s__('BillingPlans|Build smarter with intelligent AI')"
        :bottom-header="s__('BillingPlans|Accelerate development with AI guidance and automation')"
        :items="duoFeaturesBuild"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        test-id="duo-features-build"
      />
    </div>
  </gl-card>
</template>
