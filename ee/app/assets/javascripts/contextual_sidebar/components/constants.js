import { __, s__ } from '~/locale';

const DUO_PRO = 'duo_pro';
const DUO_ENTERPRISE = 'duo_enterprise';
const LEGACY_ULTIMATE = 'legacy_ultimate';
const ULTIMATE_WITH_DUO = 'ultimate';

export const TRIAL_WIDGET = {
  i18n: {
    widgetRemainingDays: s__('TrialWidget|%{daysLeft} days left in trial'),
    learnMore: s__('TrialWidget|Learn more'),
    upgradeText: s__('TrialWidget|Upgrade'),
    seeUpgradeOptionsText: s__('TrialWidget|See upgrade options'),
    dismiss: __('Dismiss'),
  },
  trialTypes: {
    [DUO_PRO]: {
      name: s__('TrialWidget|GitLab Duo Pro'),
      widgetTitle: s__('TrialWidget|GitLab Duo Pro Trial'),
      widgetTitleExpiredTrial: s__('TrialWidget|Your trial of GitLab Duo Pro has ended'),
    },
    [DUO_ENTERPRISE]: {
      name: s__('TrialWidget|GitLab Duo Enterprise'),
      widgetTitle: s__('TrialWidget|GitLab Duo Enterprise Trial'),
      widgetTitleExpiredTrial: s__('TrialWidget|Your trial of GitLab Duo Enterprise has ended'),
    },
    [LEGACY_ULTIMATE]: {
      name: s__('TrialWidget|Ultimate'),
      widgetTitle: s__('TrialWidget|Ultimate Trial'),
      widgetTitleExpiredTrial: s__('TrialWidget|Your trial of Ultimate has ended'),
    },
    [ULTIMATE_WITH_DUO]: {
      name: s__('TrialWidget|Ultimate with GitLab Duo Enterprise'),
      widgetTitle: s__('TrialWidget|Ultimate with GitLab Duo Enterprise Trial'),
      widgetTitleExpiredTrial: s__(
        'TrialWidget|Your trial of Ultimate with GitLab Duo Enterprise has ended',
      ),
    },
  },
  containerId: 'trial-sidebar-widget',
  trialUpgradeThresholdDays: 30,
  clickUpgradeLinkEventAction: 'click_upgrade_link_on_trial_widget',
  clickLearnMoreLinkEventAction: 'click_learn_more_link_on_trial_widget',
  clickSeeUpgradeOptionsLinkEventAction: 'click_see_upgrade_options_link_on_trial_widget',
  clickDismissButtonEventAction: 'click_dismiss_button_on_trial_widget',
};
