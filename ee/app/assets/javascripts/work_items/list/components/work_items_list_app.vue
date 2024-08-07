<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState, GlButton } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC } from '~/work_items/constants';
import WorkItemsListApp from '~/work_items/list/components/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import EpicsListBulkEditSidebar from 'ee/epics_list/components/epics_list_bulk_edit_sidebar.vue';
import { isLabelsWidget } from '~/work_items/utils';

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_ENUM_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    GlButton,
    WorkItemsListApp,
    EpicsListBulkEditSidebar,
  },
  inject: [
    'hasEpicsFeature',
    'showNewIssueLink',
    'canBulkEditEpics',
    'groupIssuesPath',
    'workItemType',
  ],
  data() {
    return {
      workItemUpdateCount: 0,
      bulkEditInProgress: false,
      showBulkEditSidebar: false,
    };
  },
  computed: {
    allowEpicBulkEditing() {
      return (
        this.hasEpicsFeature &&
        this.canBulkEditEpics &&
        this.workItemType === WORK_ITEM_TYPE_ENUM_EPIC
      );
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
    convertWorkItemsToIssuables(workItems) {
      return workItems.map((workItem) => ({
        labels: workItem.widgets.find(isLabelsWidget).labels,
        ...workItem,
      }));
    },
    /**
     * Bulk editing Issuables (or Epics in this case) is not supported
     * via GraphQL mutations, so we're using legacy API to do it,
     * hence we're making a POST call within the component.
     */
    async handleEpicsBulkUpdate(update) {
      this.bulkEditInProgress = true;
      try {
        await axios.post(`${this.groupIssuesPath}/bulk_update`, {
          update,
        });
        this.incrementUpdateCount();
      } catch (error) {
        createAlert({
          message: s__('Epics|Something went wrong while updating epics.'),
          captureError: true,
          error,
        });
      } finally {
        this.bulkEditInProgress = false;
        this.showBulkEditSidebar = false;
      }
    },
  },
};
</script>

<template>
  <work-items-list-app
    :show-bulk-edit-sidebar="showBulkEditSidebar"
    :ee-work-item-update-count="workItemUpdateCount"
  >
    <template v-if="hasEpicsFeature && showNewIssueLink" #nav-actions>
      <div class="gl-flex gl-gap-3">
        <gl-button
          v-if="allowEpicBulkEditing"
          class="!gl-w-auto gl-grow"
          data-testid="bulk-edit-start-button"
          :disabled="showBulkEditSidebar"
          @click="showBulkEditSidebar = true"
          >{{ __('Bulk edit') }}</gl-button
        >
        <create-work-item-modal
          class="gl-grow"
          :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
          @workItemCreated="incrementUpdateCount"
        />
      </div>
    </template>
    <template v-if="hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues :has-search="hasSearch" is-epic :is-open-tab="isOpenTab">
        <template v-if="showNewIssueLink" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="hasEpicsFeature" #page-empty-state>
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
        <template v-if="showNewIssueLink" #actions>
          <create-work-item-modal
            class="gl-grow"
            :work-item-type-name="$options.WORK_ITEM_TYPE_ENUM_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
    <template v-if="allowEpicBulkEditing" #bulk-edit-actions="{ checkedIssuables }">
      <gl-button
        variant="confirm"
        type="submit"
        form="epics-list-bulk-edit"
        :disabled="checkedIssuables.length === 0 || bulkEditInProgress"
        :loading="bulkEditInProgress"
        >{{ __('Update selected') }}</gl-button
      >
      <gl-button class="gl-float-right" @click="showBulkEditSidebar = false">{{
        __('Cancel')
      }}</gl-button>
    </template>
    <template v-if="allowEpicBulkEditing" #sidebar-items="{ checkedIssuables }">
      <epics-list-bulk-edit-sidebar
        :checked-epics="convertWorkItemsToIssuables(checkedIssuables)"
        @bulk-update="handleEpicsBulkUpdate"
      />
    </template>
  </work-items-list-app>
</template>
