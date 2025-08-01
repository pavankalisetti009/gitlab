import produce from 'immer';
import uniqueId from 'lodash/uniqueId';
import {
  DASHBOARD_SCHEMA_VERSION,
  CATEGORY_SINGLE_STATS,
  CATEGORY_CHARTS,
  CATEGORY_TABLES,
  VISUALIZATION_TYPE_DATA_TABLE,
  VISUALIZATION_TYPE_SINGLE_STAT,
} from 'ee/analytics/analytics_dashboards/constants';
import { humanize } from '~/lib/utils/text_utility';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import getAllCustomizableDashboardsQuery from '../graphql/queries/get_all_customizable_dashboards.query.graphql';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import { TYPENAME_ANALYTICS_DASHBOARD_PANEL } from '../graphql/constants';

/**
 * Updates a dashboard detail in cache from getProductAnalyticsDashboard:{slug}
 */
const updateDashboardDetailsApolloCache = ({
  apolloClient,
  dashboard,
  slug,
  fullPath,
  isProject,
  isGroup,
}) => {
  const getDashboardDetailsQuery = {
    query: getCustomizableDashboardQuery,
    variables: {
      fullPath,
      slug,
      isProject,
      isGroup,
    },
  };
  const sourceData = apolloClient.readQuery(getDashboardDetailsQuery);
  if (!sourceData) {
    // Dashboard details not yet in cache, must be a new dashboard, nothing to update
    return;
  }

  const data = produce(sourceData, (draftState) => {
    const { nodes } = isProject
      ? draftState.project.customizableDashboards
      : draftState.group.customizableDashboards;
    const updateIndex = nodes.findIndex((node) => node.slug === slug);

    if (updateIndex < 0) return;

    const updateNode = nodes[updateIndex];

    nodes.splice(updateIndex, 1, {
      ...updateNode,
      ...dashboard,
      panels: {
        ...updateNode.panels,
        nodes:
          dashboard.panels?.map((panel) => {
            const { id, ...panelRest } = panel;
            return { __typename: TYPENAME_ANALYTICS_DASHBOARD_PANEL, ...panelRest };
          }) || [],
      },
    });
  });

  apolloClient.writeQuery({
    ...getDashboardDetailsQuery,
    data,
  });
};

/**
 * Adds/updates a newly created dashboard to the dashboards list cache from getAllCustomizableDashboardsQuery
 */
const updateDashboardsListApolloCache = ({
  apolloClient,
  dashboardSlug,
  dashboard,
  fullPath,
  isProject,
  isGroup,
}) => {
  const getDashboardListQuery = {
    query: getAllCustomizableDashboardsQuery,
    variables: {
      fullPath,
      isProject,
      isGroup,
    },
  };
  const sourceData = apolloClient.readQuery(getDashboardListQuery);
  if (!sourceData) {
    // Dashboard list not yet loaded in cache, nothing to update
    return;
  }

  const data = produce(sourceData, (draftState) => {
    const { panels, ...dashboardWithoutPanels } = dashboard;
    const { nodes } = isProject
      ? draftState.project.customizableDashboards
      : draftState.group.customizableDashboards;

    const updateIndex = nodes.findIndex(({ slug }) => slug === dashboardSlug);

    // Add new dashboard if it doesn't exist
    if (updateIndex < 0) {
      nodes.push(dashboardWithoutPanels);
      return;
    }

    nodes.splice(updateIndex, 1, {
      ...nodes[updateIndex],
      ...dashboardWithoutPanels,
    });
  });

  apolloClient.writeQuery({
    ...getDashboardListQuery,
    data,
  });
};

export const updateApolloCache = ({
  apolloClient,
  slug,
  dashboard,
  fullPath,
  isProject,
  isGroup,
}) => {
  // TODO: modify to support removing dashboards from cache https://gitlab.com/gitlab-org/gitlab/-/issues/425513
  updateDashboardDetailsApolloCache({
    apolloClient,
    dashboard,
    slug,
    fullPath,
    isProject,
    isGroup,
  });
  updateDashboardsListApolloCache({ apolloClient, slug, dashboard, fullPath, isProject, isGroup });
};

/**
 * Get the category key for visualizations by their type. Default is "charts".
 */
export const getVisualizationCategory = (visualization) => {
  if (visualization.type === VISUALIZATION_TYPE_SINGLE_STAT) {
    return CATEGORY_SINGLE_STATS;
  }
  if (visualization.type === VISUALIZATION_TYPE_DATA_TABLE) {
    return CATEGORY_TABLES;
  }
  return CATEGORY_CHARTS;
};

/**
 * Maps a full hydrated dashboard (including GraphQL __typenames, and full visualization definitions) into a slimmed down version that complies with the dashboard schema definition
 */
export const getDashboardConfig = (hydratedDashboard) => {
  const { __typename: dashboardTypename, userDefined, slug, ...dashboardRest } = hydratedDashboard;

  return {
    ...dashboardRest,
    version: DASHBOARD_SCHEMA_VERSION,
    panels: hydratedDashboard.panels.map((panel) => {
      const { __typename: panelTypename, id, ...panelRest } = panel;
      const { __typename: visualizationTypename, ...visualizationRest } = panel.visualization;

      return {
        ...panelRest,
        queryOverrides: panel.queryOverrides ?? {},
        visualization: visualizationRest,
      };
    }),
  };
};

export const getUniquePanelId = () => uniqueId('panel-');

export const createNewVisualizationPanel = (visualization) => ({
  id: getUniquePanelId(),
  title: humanize(visualization.slug),
  gridAttributes: {
    width: 4,
    height: 3,
  },
  queryOverrides: {},
  options: {},
  visualization: cloneWithoutReferences({ ...visualization, errors: null }),
});

/**
 * Validator for the availableVisualizations property
 */
export const availableVisualizationsValidator = ({ loading, hasError, visualizations }) => {
  return (
    typeof loading === 'boolean' && typeof hasError === 'boolean' && Array.isArray(visualizations)
  );
};
