import { GlIcon, GlFormRadio } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { mockLifecycles } from '../mock_data';

describe('LifecycleDetail', () => {
  let wrapper;

  const mockLifecycle = {
    ...mockLifecycles[0],
    workItemTypes: [
      {
        id: 'gid://gitlab/WorkItems::Type/1',
        name: 'Issue',
        iconName: 'issue-type-issue',
        __typename: 'WorkItemType',
      },
      {
        id: 'gid://gitlab/WorkItems::Type/2',
        name: 'Task',
        iconName: 'issue-type-task',
        __typename: 'WorkItemType',
      },
    ],
  };

  const findLifecycleDetail = () => wrapper.findByTestId('lifecycle-detail');
  const findLifecycleHeading = () => wrapper.find('h5');
  const findRadioSelectionSlot = () => wrapper.find('[data-testid="lifecycle-select"]');
  const findWorkItemTypeIcons = () =>
    wrapper.findByTestId('lifecycle-37-usage').findAllComponents(GlIcon);
  const findWorkItemTypeNames = () => wrapper.findAll('[data-testid="work-item-type-name"');
  const findUsageSection = () => wrapper.find('[data-testid="lifecycle-37-usage"]');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(LifecycleDetail, {
      propsData: {
        lifecycle: mockLifecycle,
        ...props,
      },
      stubs: {
        GlIcon,
        GlFormRadio,
        WorkItemStatusBadge,
      },
    });
  };

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the component with correct test id and styling', () => {
      expect(findLifecycleDetail().exists()).toBe(true);
      expect(findLifecycleDetail().classes()).toEqual([
        'gl-border',
        'gl-rounded-lg',
        'gl-bg-white',
        'gl-px-4',
        'gl-py-4',
      ]);
    });

    it('displays lifecycle name when not default lifecycle', () => {
      expect(findLifecycleHeading().exists()).toBe(true);
      expect(findLifecycleHeading().text()).toBe(mockLifecycle.name);
    });

    it('displays work item types with icons and names', () => {
      expect(findWorkItemTypeIcons()).toHaveLength(mockLifecycle.workItemTypes.length);

      findWorkItemTypeIcons().wrappers.forEach((icon, index) => {
        expect(icon.props('name')).toBe(mockLifecycle.workItemTypes[index].iconName);
      });

      // Check that work item type names are displayed
      findWorkItemTypeNames().wrappers.forEach((span, index) => {
        expect(span.text()).toContain(mockLifecycle.workItemTypes[index].name);
      });
    });

    it('displays usage section when work item types exist', () => {
      expect(findUsageSection().exists()).toBe(true);
      expect(findUsageSection().text()).toContain('Usage');
    });
  });

  describe('when isDefaultLifecycle is true', () => {
    beforeEach(() => {
      createWrapper({ isDefaultLifecycle: true });
    });

    it('displays default statuses heading instead of lifecycle name', () => {
      expect(findLifecycleHeading().exists()).toBe(true);
      expect(findLifecycleHeading().text()).toBe('Default statuses');
    });
  });

  describe('when showRadioSelection is true', () => {
    beforeEach(() => {
      createWrapper({ showRadioSelection: true });
    });

    it('shows radio selection slot instead of heading', () => {
      expect(findLifecycleHeading().exists()).toBe(false);
      expect(findRadioSelectionSlot().exists()).toBe(true);
    });
  });

  describe('when lifecycle has no work item types', () => {
    beforeEach(() => {
      const lifecycleWithoutTypes = {
        ...mockLifecycle,
        workItemTypes: [],
      };
      createWrapper({ lifecycle: lifecycleWithoutTypes });
    });

    it('does not display the usage section', () => {
      expect(findUsageSection().exists()).toBe(false);
    });
  });
});
