import { GlEmptyState } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/list/components/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/list/components/work_items_list_app.vue';

describe('WorkItemsListApp EE component', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
  const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
  const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);
  const findBulkEditStartButton = () => wrapper.findByTestId('bulk-edit-start-button');

  const mountComponent = ({
    hasEpicsFeature = true,
    showNewIssueLink = true,
    canBulkEditEpics = true,
  } = {}) => {
    wrapper = shallowMountExtended(EEWorkItemsListApp, {
      provide: {
        hasEpicsFeature,
        showNewIssueLink,
        canBulkEditEpics,
        groupIssuesPath: 'groups/gitlab-org/-/issues',
        workItemType: 'EPIC',
      },
    });
  };

  describe('create-work-item modal', () => {
    describe.each`
      hasEpicsFeature | showNewIssueLink | exists
      ${false}        | ${false}         | ${false}
      ${true}         | ${false}         | ${false}
      ${false}        | ${true}          | ${false}
      ${true}         | ${true}          | ${true}
    `(
      'when hasEpicsFeature=$hasEpicsFeature and showNewIssueLink=$showNewIssueLink',
      ({ hasEpicsFeature, showNewIssueLink, exists }) => {
        it(`${exists ? 'renders' : 'does not render'}`, () => {
          mountComponent({ hasEpicsFeature, showNewIssueLink });

          expect(findCreateWorkItemModal().exists()).toBe(exists);
        });
      },
    );

    describe('when "workItemCreated" event is emitted', () => {
      it('increments `eeWorkItemUpdateCount` prop on WorkItemsListApp', async () => {
        mountComponent();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(0);

        findCreateWorkItemModal().vm.$emit('workItemCreated');
        await nextTick();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(1);
      });
    });
  });

  describe('empty states', () => {
    describe('when hasEpicsFeature=true', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: true });
      });

      it('renders list empty state', () => {
        expect(findListEmptyState().props()).toEqual({
          hasSearch: false,
          isEpic: true,
          isOpenTab: true,
        });
      });

      it('renders page empty state', () => {
        expect(wrapper.findComponent(GlEmptyState).props()).toMatchObject({
          description: 'Track groups of issues that share a theme, across projects and milestones',
          title:
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
        });
      });
    });

    describe('when hasEpicsFeature=false', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: false });
      });

      it('does not render list empty state', () => {
        expect(findListEmptyState().exists()).toBe(false);
      });

      it('does not render page empty state', () => {
        expect(findPageEmptyState().exists()).toBe(false);
      });
    });
  });

  describe('when bulk editing', () => {
    it('does not show bulk edit toggle by default', () => {
      mountComponent({ hasEpicsFeature: false, canBulkEditEpics: false });

      expect(findBulkEditStartButton().exists()).toBe(false);
      expect(findWorkItemsListApp().props('showBulkEditSidebar')).toBe(false);
    });

    it('shows the bulk edit toggle when the work item type is epic and the correct features are enabled', () => {
      mountComponent({ hasEpicsFeature: true, canBulkEditEpics: true });

      expect(findBulkEditStartButton().exists()).toBe(true);
    });

    it('opens the bulk update sidebar when the toggle is clicked', async () => {
      mountComponent({ hasEpicsFeature: true, canBulkEditEpics: true });

      await findBulkEditStartButton().vm.$emit('click');

      expect(findWorkItemsListApp().props('showBulkEditSidebar')).toBe(true);
    });
  });
});
