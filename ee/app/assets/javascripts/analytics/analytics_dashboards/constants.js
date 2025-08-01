import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DORA_METRICS } from '~/analytics/shared/constants';
import { formatAsPercentage } from 'ee/analytics/dora/components/util';

export const DASHBOARD_SCHEMA_VERSION = '2';

export const EVENTS_TYPES = ['pageViews', 'linkClickEvents', 'events'];

export const EVENTS_TABLE_NAME = 'TrackedEvents';
export const SESSIONS_TABLE_NAME = 'Sessions';
export const RETURNING_USERS_TABLE_NAME = 'ReturningUsers';

export const TRACKED_EVENTS_KEY = 'trackedevents';

export const NEW_DASHBOARD = () => ({
  title: '',
  version: DASHBOARD_SCHEMA_VERSION,
  description: '',
  panels: [],
  userDefined: true,
  status: null,
  errors: null,
});

export const FILE_ALREADY_EXISTS_SERVER_RESPONSE = 'A file with this name already exists';
export const DEFAULT_DASHBOARD_LOADING_ERROR = s__(
  'Analytics|Something went wrong while loading the dashboard. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}.',
);
export const DASHBOARD_REFRESH_MESSAGE = s__(
  'Analytics|Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}.',
);

export const EVENT_LABEL_CREATED_DASHBOARD = 'user_created_custom_dashboard';
export const EVENT_LABEL_EDITED_DASHBOARD = 'user_edited_custom_dashboard';

export const EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD = 'user_viewed_custom_dashboard';
export const EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD = 'user_viewed_builtin_dashboard';
export const EVENT_LABEL_VIEWED_DASHBOARD = 'user_viewed_dashboard';

export const GITLAB_DUO_CORRELATION_PROPERTY = 'correlation_id';

export const EVENT_LABEL_CLICK_METRIC_IN_DASHBOARD_TABLE = 'click_metric_in_dashboard_table';
export const AI_IMPACT_TABLE_TRACKING_PROPERTY = 'ai_impact_table';
export const VSD_COMPARISON_TABLE_TRACKING_PROPERTY = 'vsd_comparison_table';

export const EVENT_LABEL_EXCLUDE_ANONYMISED_USERS = 'exclude_anonymised_users';

export const PANEL_TROUBLESHOOTING_URL = helpPagePath(
  '/user/analytics/analytics_dashboards#troubleshooting',
);

export const AI_IMPACT_DASHBOARD = 'ai_impact';

// The URL name already in use is `value_streams_dashboard`,
// the slug name for a dashboard must match the URL path that is used
export const BUILT_IN_VALUE_STREAM_DASHBOARD = 'value_streams_dashboard';

// The URL for shared analytics dashboards is based on the name of the YAML config
// YAML configured VSD uses `/value_streams` for the custom file name
export const CUSTOM_VALUE_STREAM_DASHBOARD = 'value_streams';

export const DORA_METRICS_CHARTS_ADDITIONAL_OPTS = {
  [DORA_METRICS.DEPLOYMENT_FREQUENCY]: {},
  [DORA_METRICS.LEAD_TIME_FOR_CHANGES]: {
    yAxis: {
      minInterval: 1,
      axisLabel: {
        formatter(seconds) {
          return humanizeTimeInterval(seconds, { abbreviated: true });
        },
      },
    },
  },
  [DORA_METRICS.TIME_TO_RESTORE_SERVICE]: {
    yAxis: {
      minInterval: 1,
      axisLabel: {
        formatter(seconds) {
          return humanizeTimeInterval(seconds, { abbreviated: true });
        },
      },
    },
  },
  [DORA_METRICS.CHANGE_FAILURE_RATE]: {
    yAxis: {
      axisLabel: {
        formatter(value) {
          return formatAsPercentage(value);
        },
      },
    },
  },
};

export const VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE = 'dora_performers_score';
export const VISUALIZATION_SLUG_DORA_PROJECTS_COMPARISON = 'dora_projects_comparison';
export const VISUALIZATION_SLUG_VSD_DORA_METRICS_TABLE = 'vsd_dora_metrics_table';
export const VISUALIZATION_SLUG_VSD_SECURITY_METRICS_TABLE = 'vsd_security_metrics_table';

export const VISUALIZATION_DOCUMENTATION_LINKS = {
  [VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE]: helpPagePath(
    'user/analytics/value_streams_dashboard.md#dora-performers-score',
  ),
  [VISUALIZATION_SLUG_DORA_PROJECTS_COMPARISON]: helpPagePath(
    'user/analytics/value_streams_dashboard.md#projects-by-dora-metric',
  ),
  [VISUALIZATION_SLUG_VSD_DORA_METRICS_TABLE]: helpPagePath(
    'user/analytics/value_streams_dashboard.md#devsecops-metrics-comparison',
  ),
  [VISUALIZATION_SLUG_VSD_SECURITY_METRICS_TABLE]: helpPagePath(
    'user/analytics/value_streams_dashboard.md#devsecops-metrics-comparison',
  ),
};

export const EVENT_LABEL_VIEWED_DASHBOARD_DESIGNER = 'user_viewed_dashboard_designer';

export const VISUALIZATION_TYPE_DATA_TABLE = 'DataTable';
export const VISUALIZATION_TYPE_LINE_CHART = 'LineChart';
export const VISUALIZATION_TYPE_COLUMN_CHART = 'ColumnChart';
export const VISUALIZATION_TYPE_SINGLE_STAT = 'SingleStat';

export const CATEGORY_SINGLE_STATS = 'singleStats';
export const CATEGORY_TABLES = 'tables';
export const CATEGORY_CHARTS = 'charts';
