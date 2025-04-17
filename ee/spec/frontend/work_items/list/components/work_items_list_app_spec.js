import { GlEmptyState } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/pages/work_items_list_app.vue';
import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';

const skipReason = new SkipReason({
  name: 'WorkItemsListApp EE component',
  reason: 'Caught error after test environment was torn down',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/478775',
});

describeSkipVue3(skipReason, () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  Vue.use(VueApollo);

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
  const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
  const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);

  const baseProvide = {
    groupIssuesPath: 'groups/gitlab-org/-/issues',
    fullPath: 'gitlab-org',
  };

  const mountComponent = ({
    hasEpicsFeature = true,
    showNewWorkItem = true,
    isGroup = true,
    workItemType = WORK_ITEM_TYPE_NAME_EPIC,
    props = {},
  } = {}) => {
    wrapper = shallowMountExtended(EEWorkItemsListApp, {
      provide: {
        hasEpicsFeature,
        showNewWorkItem,
        isGroup,
        workItemType,
        ...baseProvide,
      },
      stubs: {
        EmptyStateWithoutAnyIssues: {
          template: '<div></div>',
        },
      },
      propsData: {
        ...props,
      },
    });
  };

  describe('create-work-item modal', () => {
    describe.each`
      hasEpicsFeature | showNewWorkItem | exists
      ${false}        | ${false}        | ${false}
      ${true}         | ${false}        | ${false}
      ${false}        | ${true}         | ${false}
      ${true}         | ${true}         | ${true}
    `(
      'when hasEpicsFeature=$hasEpicsFeature and showNewWorkItem=$showNewWorkItem',
      ({ hasEpicsFeature, showNewWorkItem, exists }) => {
        it(`${exists ? 'renders' : 'does not render'}`, () => {
          mountComponent({ hasEpicsFeature, showNewWorkItem });

          expect(findCreateWorkItemModal().exists()).toBe(exists);
        });
      },
    );

    it('passes the right props to modal when hasEpicsFeature is true', () => {
      mountComponent({ hasEpicsFeature: true, showNewWorkItem: true });

      expect(findCreateWorkItemModal().exists()).toBe(true);
      expect(findCreateWorkItemModal().props()).toMatchObject({
        isGroup: true,
        preselectedWorkItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
    });

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

  describe('when withTabs is false', () => {
    it('passes the correct props to WorkItemsListApp', () => {
      mountComponent({ props: { withTabs: false } });

      expect(findWorkItemsListApp().props('withTabs')).toBe(false);
    });
  });
});
