<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState } from '@gitlab/ui';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import { WORK_ITEM_TYPE_NAME_EPIC, WORK_ITEM_TYPE_NAME_ISSUE } from '~/work_items/constants';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';

import epicListQuery from '../graphql/list/get_work_items_for_epics.query.graphql';

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_NAME_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    WorkItemsListApp,
  },
  inject: ['hasEpicsFeature', 'isGroup', 'showNewWorkItem', 'workItemType'],
  props: {
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    newCommentTemplatePaths: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      workItemUpdateCount: 0,
    };
  },
  computed: {
    preselectedWorkItemType() {
      return this.isEpicsList ? WORK_ITEM_TYPE_NAME_EPIC : WORK_ITEM_TYPE_NAME_ISSUE;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
  },
  epicListQuery,
};
</script>

<template>
  <work-items-list-app
    :ee-work-item-update-count="workItemUpdateCount"
    :ee-epic-list-query="$options.epicListQuery"
    :with-tabs="withTabs"
    :new-comment-template-paths="newCommentTemplatePaths"
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
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
  </work-items-list-app>
</template>
