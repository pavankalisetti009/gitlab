if (gon.features.workItemEpicsList && gon.features.namespaceLevelWorkItems) {
  import(/* webpackChunkName: 'workItemsList' */ '~/work_items/list')
    .then(({ mountWorkItemsListApp }) => {
      mountWorkItemsListApp();
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
