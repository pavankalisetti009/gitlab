<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { findStatusWidget } from '~/work_items/utils';
import { TYPENAME_ISSUE, TYPENAME_TASK } from '~/graphql_shared/constants';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import {
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  CREATION_CONTEXT_LIST_ROUTE,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
  TOKEN_TYPE_STATUS,
  TOKEN_TITLE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TITLE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TITLE_ITERATION,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import searchIterationsQuery from 'ee/issues/list/queries/search_iterations.query.graphql';

const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');
const WeightToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue');
const HealthToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue');
const IterationToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue');

export default {
  CREATION_CONTEXT_LIST_ROUTE,
  emptyStateSvg,
  WORK_ITEM_TYPE_NAME_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    WorkItemsListApp,
    WorkItemStatusBadge,
  },
  inject: [
    'hasEpicsFeature',
    'isGroup',
    'showNewWorkItem',
    'workItemType',
    'hasCustomFieldsFeature',
    'hasIssueWeightsFeature',
    'hasIssuableHealthStatusFeature',
    'hasStatusFeature',
    'hasIterationsFeature',
  ],
  props: {
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    rootPageFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      workItemUpdateCount: 0,
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.rootPageFullPath,
          active: true,
        };
      },
      skip() {
        return !this.hasCustomFieldsFeature;
      },
      update(data) {
        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = [
            CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          ].includes(field.fieldType);

          let fieldAllowedOnWorkItem = field.workItemTypes.some(
            (type) => type.name === this.workItemType,
          );
          if (!this.isEpicsList) {
            fieldAllowedOnWorkItem = field.workItemTypes.some(
              (type) => type.name === TYPENAME_ISSUE || type.name === TYPENAME_TASK,
            );
          }

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    namespace() {
      return !this.isGroup ? WORKSPACE_PROJECT : WORKSPACE_GROUP;
    },
    preselectedWorkItemType() {
      return this.isEpicsList ? WORK_ITEM_TYPE_NAME_EPIC : WORK_ITEM_TYPE_NAME_ISSUE;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
    searchTokens() {
      const tokens = [];

      if (this.customFields.length > 0) {
        this.customFields.forEach((field) => {
          tokens.push({
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.rootPageFullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          });
        });
      }

      if (!this.isEpicsList) {
        if (this.hasIssueWeightsFeature) {
          tokens.push({
            type: TOKEN_TYPE_WEIGHT,
            title: TOKEN_TITLE_WEIGHT,
            icon: 'weight',
            token: WeightToken,
            unique: true,
          });
        }

        if (this.hasIterationsFeature) {
          tokens.push({
            type: TOKEN_TYPE_ITERATION,
            title: TOKEN_TITLE_ITERATION,
            icon: 'iteration',
            token: IterationToken,
            fetchIterations: this.fetchIterations,
            recentSuggestionsStorageKey: `${this.rootPageFullPath}-work-items-recent-tokens-iteration`,
            fullPath: this.rootPageFullPath,
            isProject: !this.isGroup,
          });
        }
      }

      if (this.showCustomStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          fullPath: this.rootPageFullPath,
          unique: true,
          operators: OPERATORS_IS,
        });
      }

      if (this.hasIssuableHealthStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_HEALTH,
          title: TOKEN_TITLE_HEALTH,
          icon: 'status-health',
          token: HealthToken,
          unique: true,
        });
      }

      return tokens;
    },
    showCustomStatusFeature() {
      return this.hasStatusFeature && !this.isEpicsList;
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
    hasStatus(issuable) {
      return Boolean(findStatusWidget(issuable)?.status);
    },
    issuableStatusItem(issuable) {
      return findStatusWidget(issuable)?.status || {};
    },
    async fetchIterations(search) {
      const id = Number(search);
      const variables =
        !search || Number.isNaN(id)
          ? { fullPath: this.rootPageFullPath, search, isProject: !this.isGroup }
          : { fullPath: this.rootPageFullPath, id, isProject: !this.isGroup };

      variables.state = 'all';

      return this.$apollo
        .query({
          query: searchIterationsQuery,
          variables,
        })
        .then(({ data }) => data[this.namespace]?.iterations.nodes)
        .catch(() => []);
    },
  },
};
</script>

<template>
  <work-items-list-app
    :ee-work-item-update-count="workItemUpdateCount"
    :ee-search-tokens="searchTokens"
    :root-page-full-path="rootPageFullPath"
    :with-tabs="withTabs"
  >
    <template v-if="isEpicsList && hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues
        :has-search="hasSearch"
        :is-epic="isEpicsList"
        :is-open-tab="isOpenTab"
      >
        <template v-if="showNewWorkItem" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :creation-context="$options.CREATION_CONTEXT_LIST_ROUTE"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="preselectedWorkItemType"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="isEpicsList && hasEpicsFeature" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewWorkItem" #actions>
          <create-work-item-modal
            class="gl-grow"
            :creation-context="$options.CREATION_CONTEXT_LIST_ROUTE"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
    <template #custom-status="{ issuable = {} }">
      <work-item-status-badge v-if="hasStatus(issuable)" :item="issuableStatusItem(issuable)" />
    </template>
  </work-items-list-app>
</template>
