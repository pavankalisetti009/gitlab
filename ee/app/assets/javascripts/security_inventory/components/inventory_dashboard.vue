<script>
import {
  GlTableLite,
  GlIcon,
  GlButton,
  GlSkeletonLoader,
  GlEmptyState,
  GlTooltipDirective,
  GlBreadcrumb,
  GlLink,
} from '@gitlab/ui';
import EMPTY_SUBGROUP_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-projects-md.svg?url';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, n__, sprintf } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { createAlert } from '~/alert';
import { getLocationHash, PATH_SEPARATOR } from '~/lib/utils/url_utility';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import VulnerabilityIndicator from './vulnerability_indicator.vue';

export default {
  components: {
    GlTableLite,
    GlIcon,
    ProjectAvatar,
    GlButton,
    GlSkeletonLoader,
    GlEmptyState,
    GlBreadcrumb,
    GlLink,
    VulnerabilityIndicator,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['groupFullPath'],
  i18n: {
    emptyStateTitle: s__('SecurityInventory|No projects found.'),
    emptyStateDescription: s__(
      'SecurityInventory|Add project to this group to start tracking their security posture.',
    ),
    errorFetchingChildren: s__(
      'SecurityInventory||An error occurred while fetching subgroups and projects. Please try again.',
    ),
    projectConfigurationTooltipTitle: s__('SecurityInventory|Manage security configuration'),
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
    transformData(data) {
      const groupData = data?.group;
      if (!groupData) return [];

      return [
        ...this.transformGroups(groupData?.descendantGroups?.nodes),
        ...this.transformProjects(groupData?.projects?.nodes),
      ];
    },
    transformGroups(nodes) {
      return nodes.map(
        ({
          id,
          name,
          avatarUrl,
          webUrl,
          fullPath,
          descendantGroupsCount,
          projectsCount,
          vulnerabilitySeveritiesCount,
        }) => ({
          id,
          type: 'group',
          name,
          avatarUrl,
          webUrl,
          fullPath,
          descendantGroupsCount,
          projectsCount,
          vulnerabilitySeveritiesCount,
        }),
      );
    },
    transformProjects(nodes) {
      return nodes.map(
        ({ id, name, avatarUrl, webUrl, fullPath, vulnerabilitySeveritiesCount }) => ({
          id,
          type: 'project',
          name,
          avatarUrl,
          webUrl,
          fullPath,
          vulnerabilitySeveritiesCount,
        }),
      );
    },
    isSubGroup(item) {
      return item.type === 'group';
    },
    iconName(item) {
      return this.isSubGroup(item) ? 'subgroup' : 'project';
    },
    projectAndSubgroupCountText(item) {
      const projectsCount = n__('%d project', '%d projects', item.projectsCount);
      const subGroupsCount = n__('%d subgroup', '%d subgroups', item.descendantGroupsCount);

      return sprintf(__('%{projectsCount}, %{subGroupsCount}'), {
        projectsCount,
        subGroupsCount,
      });
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
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <gl-breadcrumb :items="crumbs" :auto-resize="true" size="md" class="gl-mb-5" />
    <template v-if="isLoading">
      <gl-skeleton-loader />
    </template>
    <template v-else-if="!hasChildren">
      <gl-empty-state
        :title="$options.i18n.emptyStateTitle"
        :description="$options.i18n.emptyStateDescription"
        :svg-path="$options.EMPTY_SUBGROUP_SVG"
        :svg-height="150"
      />
    </template>
    <gl-table-lite v-else :items="children" :fields="$options.fields" hover>
      <template #cell(name)="{ item }">
        <component
          :is="isSubGroup(item) ? 'gl-link' : 'div'"
          class="gl-flex gl-items-center !gl-text-default hover:gl-no-underline focus:gl-no-underline focus:gl-outline-none"
          :href="isSubGroup(item) ? `#${item.fullPath}` : undefined"
        >
          <gl-icon :name="iconName(item)" variant="subtle" class="gl-mr-4" />
          <project-avatar
            class="gl-mr-4"
            :project-id="item.id"
            :project-name="item.name"
            :project-avatar-url="item.avatarUrl"
          />
          <div class="gl-flex gl-flex-col">
            <span class="gl-text-base gl-font-bold"> {{ item.name }} </span>
            <span v-if="isSubGroup(item)" class="gl-font-normal gl-text-subtle">
              {{ projectAndSubgroupCountText(item) }}
            </span>
          </div>
        </component>
      </template>

      <template #cell(vulnerabilities)="{ item: { vulnerabilitySeveritiesCount } }">
        <vulnerability-indicator :counts="vulnerabilitySeveritiesCount" />
      </template>

      <template #cell(toolCoverage)="">
        {{ __('N/A') }}
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
