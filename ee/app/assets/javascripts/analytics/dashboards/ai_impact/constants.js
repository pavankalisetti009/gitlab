import { pick } from 'lodash';
import { s__ } from '~/locale';
import { AI_METRICS, UNITS } from '~/analytics/shared/constants';

import { helpPagePath } from '~/helpers/help_page_helper';
import { TABLE_METRICS, PIPELINE_ANALYTICS_TABLE_METRICS } from '../constants';

export const SUPPORTED_AI_METRICS = [
  AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
  AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
  AI_METRICS.DUO_CHAT_USAGE_RATE,
  AI_METRICS.DUO_RCA_USAGE_RATE,
  AI_METRICS.DUO_USED_COUNT,
];
export const HIDE_METRIC_DRILL_DOWN = [
  AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
  AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
  AI_METRICS.DUO_CHAT_USAGE_RATE,
  AI_METRICS.DUO_RCA_USAGE_RATE,
  AI_METRICS.DUO_USED_COUNT,
];

// The AI impact metrics supported for over time tiles
export const AI_IMPACT_OVER_TIME_METRICS = {
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Code Suggestions usage'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
    label: s__('AiImpactAnalytics|Code Suggestions acceptance rate'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Duo Chat usage'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.DUO_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Assigned Duo seat engagement'),
    units: UNITS.PERCENT,
  },
};

export const AI_IMPACT_USAGE_METRICS = {
  ...AI_IMPACT_OVER_TIME_METRICS,
  [AI_METRICS.DUO_RCA_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Duo RCA usage'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.DUO_USED_COUNT]: {
    label: s__('AiImpactAnalytics|Duo features usage'),
    units: UNITS.COUNT,
  },
};

export const AI_IMPACT_TABLE_METRICS = {
  ...TABLE_METRICS,
  ...PIPELINE_ANALYTICS_TABLE_METRICS,
  ...pick(AI_IMPACT_USAGE_METRICS, SUPPORTED_AI_METRICS),
};

export const AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS = {
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|Code contributors with assigned Duo seats who used Code Suggestions. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/project/repository/code_suggestions/_index', {
      anchor: 'use-code-suggestions',
    }),
  },
  [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
    description: s__(
      'AiImpactAnalytics|Code Suggestions accepted out of total Code Suggestions generated. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/project/repository/code_suggestions/_index', {
      anchor: 'use-code-suggestions',
    }),
  },
  [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|Users with assigned Duo seats who used Duo Chat. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/gitlab_duo_chat/_index'),
  },
  [AI_METRICS.DUO_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|Users with assigned Duo seats who used at least one Duo feature. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('subscriptions/subscription-add-ons', {
      anchor: 'assign-gitlab-duo-seats',
    }),
  },
};

export const AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS = {
  // Code suggestions usage only started being tracked April 4, 2024
  // https://gitlab.com/gitlab-org/gitlab/-/issues/456108
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    startDate: new Date('2024-04-04'),
    message: s__(
      'AiImpactAnalytics|The usage data may be incomplete due to backend calculations starting after upgrade to GitLab 16.11. For more information, see %{linkStart}epic 12978%{linkEnd}.',
    ),
    link: 'https://gitlab.com/groups/gitlab-org/-/epics/12978',
  },
  // Duo RCA usage only started being tracked April 23, 2025
  // https://gitlab.com/gitlab-org/gitlab/-/issues/486523
  [AI_METRICS.DUO_RCA_USAGE_RATE]: {
    startDate: new Date('2025-04-23'),
    message: s__(
      'AiImpactAnalytics|Data available after upgrade to GitLab 18.0. %{linkStart}Learn more%{linkEnd}.',
    ),
    link: helpPagePath('user/analytics/duo_and_sdlc_trends', {
      anchor: 'duo-usage-metrics',
    }),
  },
};
