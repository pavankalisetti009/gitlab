import { isEqual } from 'lodash';
import { convertToGraphQLIds, convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { formatDate, getDateInPast, pikadayToString } from '~/lib/utils/datetime_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import { queryToObject } from '~/lib/utils/url_utility';
import { CURRENT_DATE } from '../audit_events/constants';
import {
  FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  FRAMEWORKS_FILTER_TYPE_PROJECT,
  GRAPHQL_FRAMEWORK_TYPE,
} from './constants';

export const isTopLevelGroup = (groupPath, rootPath) => groupPath === rootPath;

export const convertProjectIdsToGraphQl = (projectIds) =>
  convertToGraphQLIds(
    TYPENAME_PROJECT,
    projectIds.filter((id) => Boolean(id)),
  );

export const convertFrameworkIdToGraphQl = (frameworId) =>
  convertToGraphQLId(GRAPHQL_FRAMEWORK_TYPE, frameworId);

export const parseViolationsQueryFilter = ({
  mergedBefore,
  mergedAfter,
  projectIds,
  targetBranch,
}) => ({
  projectIds: projectIds ? convertProjectIdsToGraphQl(projectIds) : [],
  mergedBefore: formatDate(mergedBefore, ISO_SHORT_FORMAT, true),
  mergedAfter: formatDate(mergedAfter, ISO_SHORT_FORMAT, true),
  targetBranch,
});

export const buildDefaultViolationsFilterParams = (queryString) => ({
  mergedAfter: pikadayToString(getDateInPast(CURRENT_DATE, 30)),
  mergedBefore: pikadayToString(CURRENT_DATE),
  ...queryToObject(queryString, { gatherArrays: true }),
});

export function mapFiltersToUrlParams(filters) {
  const urlParams = {};

  const projectFilter = filters.find((filter) => filter.type === FRAMEWORKS_FILTER_TYPE_PROJECT);

  if (projectFilter) {
    urlParams.project = projectFilter.value.data;
  }

  const frameworkFilters = filters.filter(
    (filter) => filter.type === FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
  );

  const frameworksInclude = frameworkFilters
    .filter((filter) => filter.value.operator !== '!=')
    .map((filter) => filter.value.data);

  const frameworksExclude = frameworkFilters
    .filter((filter) => filter.value.operator === '!=')
    .map((filter) => filter.value.data);

  if (frameworksInclude.length > 0) {
    urlParams['framework[]'] = frameworksInclude;
  }

  if (frameworksExclude.length > 0) {
    urlParams['not[framework][]'] = frameworksExclude;
  }

  return urlParams;
}

export function mapQueryToFilters(queryParams) {
  const filters = [];
  const { project } = queryParams;
  const frameworks = queryParams['framework[]'];
  const notFrameworks = queryParams['not[framework][]'];

  const getFrameworkFilters = (params, operator) => {
    const frameworksArray = Array.isArray(params) ? params : [params];
    frameworksArray.forEach((framework) => {
      filters.push({
        type: FRAMEWORKS_FILTER_TYPE_FRAMEWORK,
        value: { data: framework, operator },
      });
    });
  };

  if (frameworks) {
    getFrameworkFilters(frameworks, '=');
  }

  if (notFrameworks) {
    getFrameworkFilters(notFrameworks, '!=');
  }

  if (project) {
    filters.push({
      type: FRAMEWORKS_FILTER_TYPE_PROJECT,
      value: { data: project, operator: 'matches' },
    });
  }

  return filters;
}

export const checkFilterForChange = ({ currentFilters = {}, newFilters = {} }) => {
  const filterKeys = ['project', 'framework[]', 'not[framework][]'];

  return filterKeys.some((key) => !isEqual(currentFilters[key], newFilters[key]));
};

export function mapStandardsAdherenceQueryToFilters(filters) {
  const filterParams = {};

  const checkSearch = filters?.find((filter) => filter.type === 'check');
  filterParams.checkName = checkSearch?.value?.data ?? undefined;

  const standardSearch = filters?.find((filter) => filter.type === 'standard');
  filterParams.standard = standardSearch?.value?.data ?? undefined;

  const projectIdsSearch = filters?.find((filter) => filter.type === 'project');
  filterParams.projectIds = projectIdsSearch?.value?.data ?? undefined;

  return filterParams;
}
