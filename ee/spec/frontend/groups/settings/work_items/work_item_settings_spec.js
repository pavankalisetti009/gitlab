import { shallowMount } from '@vue/test-utils';
import CustomFieldsList from 'ee/groups/settings/work_items/custom_fields/custom_fields_list.vue';
import CustomStatusSettings from 'ee/groups/settings/work_items/custom_status/custom_status_settings.vue';
import WorkItemSettings from 'ee/groups/settings/work_items/work_item_settings.vue';

describe('WorkItemSettings', () => {
  let wrapper;
  const fullPath = 'group/project';

  const createComponent = () => {
    wrapper = shallowMount(WorkItemSettings, {
      propsData: {
        fullPath,
      },
    });
  };

  const findCustomFieldsList = () => wrapper.findComponent(CustomFieldsList);
  const findCustomStatusSettings = () => wrapper.findComponent(CustomStatusSettings);

  it('always renders CustomFieldsList component with correct props', () => {
    createComponent();

    expect(findCustomFieldsList().exists()).toBe(true);
    expect(findCustomFieldsList().props('fullPath')).toBe(fullPath);
  });

  it('renders CustomStatusSettings component with correct props', () => {
    createComponent();

    expect(findCustomStatusSettings().exists()).toBe(true);
  });
});
