import { WORKSPACE_GROUP } from '~/issues/constants';
import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';

if (gon.features.workItemEpicsList && gon.features.namespaceLevelWorkItems) {
  import(/* webpackChunkName: 'workItemsApp' */ '~/work_items/index')
    .then(({ initWorkItemsRoot }) => {
      initWorkItemsRoot({ workItemType: WORK_ITEM_TYPE_NAME_EPIC, workspaceType: WORKSPACE_GROUP });
    })
    .catch(() => {});
} else {
  import(/* webpackChunkName: 'epicsList' */ 'ee/epics_list/epics_list_bundle')
    .then(({ default: initEpicsList }) => {
      initEpicsList({
        mountPointSelector: '#js-epics-list',
      });
    })
    .catch(() => {});
}
