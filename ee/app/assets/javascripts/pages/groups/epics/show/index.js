const initWorkItemEpicPage = async () => {
  const [{ WORKSPACE_GROUP }, { initWorkItemsRoot }] = await Promise.all([
    import('~/issues/constants'),
    import('~/work_items'),
  ]);

  initWorkItemsRoot({ workspaceType: WORKSPACE_GROUP });
};

const initLegacyEpicPage = async () => {
  const [
    { addShortcutsExtension },
    { default: ShortcutsEpic },
    { default: initEpicApp },
    { default: initNotesApp },
    { default: ZenMode },
    { default: initAwardsApp },
  ] = await Promise.all([
    import('~/behaviors/shortcuts'),
    import('ee/behaviors/shortcuts/shortcuts_epic'),
    import('ee/epic/epic_bundle'),
    import('~/notes'),
    import('~/zen_mode'),
    import('~/emoji/awards_app'),
  ]);

  initNotesApp();
  initEpicApp();

  import('ee/linked_epics/linked_epics_bundle').then((m) => m.default()).catch(() => {});

  requestIdleCallback(() => {
    addShortcutsExtension(ShortcutsEpic);
    initAwardsApp(document.getElementById('js-vue-awards-block'));
    new ZenMode(); // eslint-disable-line no-new
  });
};

if (gon.features.workItemEpics) {
  initWorkItemEpicPage();
} else {
  initLegacyEpicPage();
}
