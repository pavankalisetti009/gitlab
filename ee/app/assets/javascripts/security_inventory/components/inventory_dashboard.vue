<script>
import {
  GlTableLite,
  GlButton,
  GlSkeletonLoader,
  GlTooltipDirective,
  GlBreadcrumb,
  GlPopover,
} from '@gitlab/ui';
import EMPTY_SUBGROUP_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-projects-md.svg?url';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getLocationHash, PATH_SEPARATOR } from '~/lib/utils/url_utility';
import { SEVERITY_CLASS_NAME_MAP } from 'ee/vue_shared/security_reports/components/constants';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import { isSubGroup } from '../utils';
import VulnerabilityIndicator from './vulnerability_indicator.vue';
import ProjectVulnerabilityCounts from './project_vulnerability_counts.vue';
import ProjectToolCoverageIndicator from './project_tool_coverage_indicator.vue';
import GroupToolCoverageIndicator from './group_tool_coverage_indicator.vue';
import EmptyState from './empty_state.vue';
import NameCell from './name_cell.vue';

export default {
  components: {
    GlTableLite,
    GlButton,
    GlSkeletonLoader,
    GlBreadcrumb,
    VulnerabilityIndicator,
    GlPopover,
    ProjectVulnerabilityCounts,
    GroupToolCoverageIndicator,
    ProjectToolCoverageIndicator,
    EmptyState,
    NameCell,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['groupFullPath', 'newProjectPath'],
  i18n: {
    errorFetchingChildren: s__(
      'SecurityInventory||An error occurred while fetching subgroups and projects. Please try again.',
    ),
    projectConfigurationTooltipTitle: s__('SecurityInventory|Manage security configuration'),
    projectVulnerabilitiesTooltipTitle: s__('SecurityInventory|Project vulnerabilities'),
  },
  fields: [
    { key: 'name', label: __('Name') },
    { key: 'vulnerabilities', label: __('Vulnerabilities') },
    { key: 'toolCoverage', label: __('Tool Coverage') },
    { key: 'actions', label: '' },
  ],
  EMPTY_SUBGROUP_SVG,
  data() {
    return {
      children: [],
      activeFullPath: this.groupFullPath,
    };
  },
  apollo: {
    children: {
      query: SubgroupsAndProjectsQuery,
      variables() {
        return {
          fullPath: this.activeFullPath,
        };
      },
      update(data) {
        return this.transformData(data);
      },
      error(error) {
        createAlert({
          message: this.$options.i18n.errorFetchingChildren,
          error,
          captureError: true,
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.children.loading;
    },
    hasChildren() {
      return this.children.length > 0;
    },
    crumbs() {
      const pathParts = this.activeFullPath.split(PATH_SEPARATOR);
      let cumulativePath = '';

      return pathParts.map((path) => {
        cumulativePath = cumulativePath ? `${cumulativePath}${PATH_SEPARATOR}${path}` : path;
        return {
          text: path,
          to: {
            hash: `#${cumulativePath}`,
          },
        };
      });
    },
  },
  created() {
    this.handleLocationHashChange();
    window.addEventListener('hashchange', this.handleLocationHashChange);
  },
  beforeDestroy() {
    window.removeEventListener('hashchange', this.handleLocationHashChange);
  },
  methods: {
    isSubGroup,
    transformData(data) {
      const groupData = data?.group;
      if (!groupData) return [];

      return [
        ...this.transformGroups(groupData?.descendantGroups?.nodes),
        ...this.transformProjects(groupData?.projects?.nodes),
      ];
    },

    transformGroups(nodes) {
      return (
        nodes?.map(
          ({
            __typename,
            id,
            name,
            avatarUrl,
            webUrl,
            fullPath,
            descendantGroupsCount,
            projectsCount,
            vulnerabilitySeveritiesCount,
          }) => ({
            __typename,
            id,
            name,
            avatarUrl,
            webUrl,
            fullPath,
            descendantGroupsCount,
            projectsCount,
            vulnerabilitySeveritiesCount,
          }),
        ) || []
      );
    },

    transformProjects(nodes) {
      return (
        nodes?.map(
          ({
            __typename,
            id,
            name,
            avatarUrl,
            webUrl,
            fullPath,
            vulnerabilitySeveritiesCount,
            securityScanners,
          }) => ({
            __typename,
            id,
            name,
            avatarUrl,
            webUrl,
            fullPath,
            vulnerabilitySeveritiesCount,
            securityScanners,
          }),
        ) || []
      );
    },
    projectSecurityConfigurationPath(item) {
      return item?.webUrl ? `${item.webUrl}/-/security/configuration` : '#';
    },
    handleLocationHashChange() {
      let hash = getLocationHash();
      if (!hash) {
        hash = this.groupFullPath;
      }
      this.activeFullPath = hash;
    },
    vulnerabilitiesCountsObject(vulnerabilitySeveritiesCount) {
      return Object.entries(vulnerabilitySeveritiesCount)
        .filter(([key]) => key !== '__typename')
        .map(([key, value]) => ({
          label: key,
          value,
          icon: `severity-${key}`,
          iconColor: SEVERITY_CLASS_NAME_MAP[key],
        }));
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <gl-breadcrumb :items="crumbs" :auto-resize="true" size="md" class="gl-mb-5" />
    <template v-if="isLoading">
      <gl-skeleton-loader />
    </template>
    <template v-else-if="!hasChildren"><empty-state /></template>
    <gl-table-lite v-else :items="children" :fields="$options.fields" hover>
      <template #cell(name)="{ item = {} }">
        <name-cell :item="item" />
      </template>

      <template #cell(vulnerabilities)="{ item: { vulnerabilitySeveritiesCount, webUrl }, index }">
        <div :id="`vulnerabilities-count-${index}`" class="gl-cursor-pointer">
          <vulnerability-indicator :counts="vulnerabilitySeveritiesCount" />
        </div>
        <gl-popover
          :title="$options.i18n.projectVulnerabilitiesTooltipTitle"
          :target="`vulnerabilities-count-${index}`"
          show-close-button
        >
          <project-vulnerability-counts
            :severity-items="vulnerabilitiesCountsObject(vulnerabilitySeveritiesCount)"
            :web-url="webUrl"
          />
        </gl-popover>
      </template>

      <template #cell(toolCoverage)="{ item }">
        <div id="tool-coverage" class="gl-cursor-pointer">
          <group-tool-coverage-indicator v-if="isSubGroup(item)" />
          <project-tool-coverage-indicator
            v-else
            :security-scanners="item.securityScanners"
            :project-name="item.name"
          />
        </div>
      </template>

      <template #cell(actions)="{ item }">
        <gl-button
          v-if="!isSubGroup(item)"
          v-gl-tooltip.hover.left
          :href="projectSecurityConfigurationPath(item)"
          class="gl-ml-3"
          :aria-label="$options.i18n.projectConfigurationTooltipTitle"
          :title="$options.i18n.projectConfigurationTooltipTitle"
          icon="settings"
        />
      </template>
    </gl-table-lite>
  </div>
</template>
