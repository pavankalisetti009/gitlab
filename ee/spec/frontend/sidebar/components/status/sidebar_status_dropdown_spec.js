import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { unionBy } from 'lodash';
import { GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SidebarStatusDropdown from 'ee/sidebar/components/status/sidebar_status_dropdown.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import { namespaceWorkItemTypesQueryResponse } from 'jest/work_items/mock_data';

describe('SidebarStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const namespaceQueryHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);

  let allowedStatus = [];

  namespaceWorkItemTypesQueryResponse.data.workspace?.workItemTypes?.nodes?.forEach((type) => {
    const statusWidget = type.widgetDefinitions.find(
      (widget) => widget.type === WIDGET_TYPE_STATUS,
    );
    if (statusWidget) {
      allowedStatus = unionBy(allowedStatus, statusWidget.allowedStatuses, 'id');
    }
  });

  const createComponent = ({
    mountFn = shallowMountExtended,
    fullPath = 'gitlab-org/gitlab-test',
    queryHandler = namespaceQueryHandler,
  } = {}) => {
    const mockApollo = createMockApollo([[namespaceWorkItemTypesQuery, queryHandler]]);
    wrapper = mountFn(SidebarStatusDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath,
      },
    });
  };

  const findSidebarDropdownWidget = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItems = () => wrapper.findAllByTestId('status-list-item');

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('shown');
  };

  const createComponentAndShowDropdown = async () => {
    createComponent();

    showDropdown();
    await waitForPromises();
  };

  it('has "Select status" header text', async () => {
    createComponent();
    await waitForPromises();

    expect(findSidebarDropdownWidget().props('headerText')).toBe('Select status');
  });

  describe('Dropdown options', () => {
    it('calls `namespaceWorkItemTypesHandler` with variables when dropdown is opened', async () => {
      await createComponentAndShowDropdown();

      expect(namespaceQueryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org/gitlab-test',
      });
    });

    it('searches the options on frontend', async () => {
      await createComponentAndShowDropdown();

      findSidebarDropdownWidget().vm.$emit('search', 'in progress');
      await nextTick();

      expect(findSidebarDropdownWidget().props('items')).toHaveLength(1);
    });

    it('resets the options on frontend when dropdown hidden after search', async () => {
      createComponent({ mountFn: mountExtended });

      showDropdown();
      await waitForPromises();

      findSidebarDropdownWidget().vm.$emit('search', 'in progress');
      await nextTick();

      expect(findSidebarDropdownWidget().props('items')).toHaveLength(1);

      await findSidebarDropdownWidget().vm.$emit('hidden');

      showDropdown();
      await nextTick();

      expect(findSidebarDropdownWidget().props('items')).toHaveLength(allowedStatus.length);
    });

    it('shows the loading indicator when fetching the status options', async () => {
      createComponent();

      showDropdown();

      await nextTick();

      expect(findSidebarDropdownWidget().props('searching')).toBe(true);
    });

    it('shows the status in dropdown when the items have finished fetching', async () => {
      createComponent({ mountFn: mountExtended });

      showDropdown();
      await waitForPromises();

      const dropdownItems = findDropdownItems();
      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('items')).toHaveLength(allowedStatus.length);
      expect(dropdownItems).toHaveLength(allowedStatus.length);

      const dropdownItemIcon = dropdownItems.at(0).findComponent(GlIcon);
      expect(dropdownItemIcon.exists()).toBe(true);
      expect(dropdownItemIcon.props('name')).toBe(allowedStatus[0].iconName);
      expect(dropdownItemIcon.attributes('style')).toBe('color: rgb(115, 114, 120);');
    });
  });
});
