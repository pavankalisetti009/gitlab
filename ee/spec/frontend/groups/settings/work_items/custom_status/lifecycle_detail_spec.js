import { GlIcon, GlFormRadio } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import LifecycleNameForm from 'ee/groups/settings/work_items/custom_status/lifecycle_name_form.vue';
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

  const lifecycleId = getIdFromGraphQLId(mockLifecycle.id);

  const findLifecycleDetail = () => wrapper.findByTestId('lifecycle-detail');
  const findRadioSelectionSlot = () => wrapper.findByTestId(`lifecycle-${lifecycleId}-select`);
  const findWorkItemTypeIcons = () =>
    wrapper.findByTestId(`lifecycle-${lifecycleId}-usage`).findAllComponents(GlIcon);
  const findWorkItemTypeNames = () => wrapper.findAllByTestId('work-item-type-name');
  const findUsageSection = () => wrapper.findByTestId(`lifecycle-${lifecycleId}-usage`);
  const findLifecycleForm = () => wrapper.findComponent(LifecycleNameForm);

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(LifecycleDetail, {
      propsData: {
        lifecycle: mockLifecycle,
        fullPath: 'test-group',
        ...props,
      },
      stubs: {
        GlIcon,
        GlFormRadio,
        WorkItemStatusBadge,
        LifecycleNameForm,
      },
    });
  };

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper({ showUsageSection: true });
    });

    it('renders the component with correct test id and styling', () => {
      expect(findLifecycleDetail().exists()).toBe(true);
      expect(findLifecycleDetail().classes()).toEqual([
        'gl-border',
        'gl-rounded-lg',
        'gl-bg-white',
        'gl-px-4',
        'gl-pt-4',
      ]);
    });

    it('renders lifecycle form with correct props when not a default cycle', () => {
      expect(findLifecycleForm().props('isDefaultLifecycle')).toBe(false);
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
      expect(findUsageSection().text()).toContain('Usage:');
    });
  });

  describe('when isDefaultLifecycle is true', () => {
    beforeEach(() => {
      createWrapper({ isDefaultLifecycle: true });
    });

    it('renders lifecycle form with correct props when default lifecycle', () => {
      expect(findLifecycleForm().props('isDefaultLifecycle')).toBe(true);
    });
  });

  describe('when showRadioSelection is true', () => {
    beforeEach(() => {
      createWrapper({ showRadioSelection: true });
    });

    it('shows radio selection slot instead of heading', () => {
      expect(findLifecycleForm().exists()).toBe(false);
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
