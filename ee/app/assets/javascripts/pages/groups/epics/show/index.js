import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';
import { NAMESPACE_GROUP } from '~/issues/constants';
import { initWorkItemsRoot } from '~/work_items';

initWorkItemsRoot({ workItemType: WORK_ITEM_TYPE_NAME_EPIC, workspaceType: NAMESPACE_GROUP });
