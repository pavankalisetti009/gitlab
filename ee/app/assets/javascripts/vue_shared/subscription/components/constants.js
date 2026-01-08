import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL } from '~/constants';

export const TRIAL_ACTIVE_FEATURE_HIGHLIGHTS = {
  header: s__('BillingPlans|Get the most from your trial'),
  subheader: s__('BillingPlans|Explore these Premium features to optimize your GitLab experience.'),
  features: [
    {
      id: 'duoChat',
      iconName: 'duo-chat',
      variant: 'default',
      title: 'GitLab Duo',
      description: s__(
        'BillingPlans|AI-powered features that help you write code, understand your work, and automate tasks across your workflow.',
      ),
      docsLink: helpPagePath('/user/gitlab_duo_chat/_index.md'),
    },
    {
      id: 'epics',
      iconName: 'work-item-epic',
      variant: 'default',
      title: s__('BillingPlans|Epics'),
      description: s__(
        'BillingPlans|Track groups of related issues to manage large initiatives and monitor progress toward long-term goals.',
      ),
      docsLink: helpPagePath('/user/group/epics/_index.md'),
    },
    {
      id: 'repositoryPullMirroring',
      iconName: 'deployments',
      variant: 'default',
      title: s__('BillingPlans|Repository pull mirroring'),
      description: s__(
        'BillingPlans|Automatically sync branches, tags, and commits from an external repository with GitLab.',
      ),
      docsLink: helpPagePath('/user/project/repository/mirror/pull'),
    },
    {
      id: 'mergeTrains',
      iconName: 'merge',
      variant: 'default',
      title: s__('BillingPlans|Merge trains'),
      description: s__(
        'BillingPlans|Automatically merge changes in sequence to prevent conflicts and keep your branch stable.',
      ),
      docsLink: helpPagePath('/ci/pipelines/merge_trains'),
    },
    {
      id: 'escalationPolicies',
      iconName: 'shield',
      variant: 'default',
      title: s__('BillingPlans|Escalation policies'),
      description: s__(
        'BillingPlans|Automatically notify the next responder when critical alerts are unacknowledged and ensure no incident is missed.',
      ),
      docsLink: helpPagePath('/operations/incident_management/escalation_policies'),
    },
    {
      id: 'mergeRequestApprovals',
      iconName: 'approval',
      variant: 'default',
      title: s__('BillingPlans|Merge request approvals'),
      description: s__(
        'BillingPlans|Control who can approve merge requests to ensure code quality and compliance.',
      ),
      docsLink: helpPagePath('/user/project/merge_requests/approvals/settings'),
    },
  ],
  ctaLabel: s__('BillingPlans|Choose Premium'),
};

export const FEATURE_HIGHLIGHTS = {
  trialActive: TRIAL_ACTIVE_FEATURE_HIGHLIGHTS,
  trialExpired: {
    header: s__('BillingPlans|Level up with Premium'),
    subheader: s__(
      "BillingPlans|Upgrade and unlock advanced features that boost your team's productivity instantly.",
    ),
    features: [
      {
        id: 'aiChat',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Chat in the IDE'),
      },
      {
        id: 'aiCode',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Code Suggestions in the IDE'),
      },
      {
        id: 'ciCd',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Advanced CI/CD'),
      },
      {
        id: 'projectManagement',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Team Project Management'),
      },
    ],
    ctaLabel: s__('BillingPlans|Upgrade to Premium'),
  },
  notInTrialSaas: {
    header: s__('BillingPlans|Get the most out of GitLab with Ultimate and GitLab Duo Enterprise'),
    subheader: s__(
      'BillingPlans|Start an Ultimate trial with GitLab Duo Enterprise to try the complete set of features from GitLab.',
    ),
    features: [
      {
        id: 'aiChat',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Chat in the IDE'),
      },
      {
        id: 'aiCode',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|AI Code Suggestions in the IDE'),
      },
      {
        id: 'ciCd',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Advanced CI/CD'),
      },
      {
        id: 'noCreditCard',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|No credit card required'),
      },
    ],
    ctaLabel: s__('BillingPlans|Start free trial'),
  },
  notInTrialSM: {
    header: s__('BillingPlans|Get the most out of GitLab with Ultimate'),
    subheader: s__(
      'BillingPlans|Start an Ultimate trial to try the complete set of features from GitLab.',
    ),
    features: [
      {
        id: 'ciCd',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Advanced CI/CD'),
      },
      {
        id: 'mergeRequestApprovals',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Merge request approvals'),
      },
      {
        id: 'mergeTrains',
        iconName: 'check',
        variant: 'info',
        title: s__('BillingPlans|Merge trains'),
      },
      {
        id: 'additionalFeatures',
        iconName: 'plus',
        variant: 'info',
        title: s__('BillingPlans|Additional features'),
        showAsLink: true,
        docsLink: `${PROMO_URL}/pricing/feature-comparison/`,
        tracking: { 'data-event-tracking': 'click_sm_additional_features_subscription_page' },
      },
    ],
    ctaLabel: s__('BillingPlans|Start free trial'),
    secondaryCtaLabel: s__('BillingPlans|Explore plans'),
  },
};
