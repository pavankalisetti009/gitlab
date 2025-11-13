import { shallowMount } from '@vue/test-utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AdminDataManagementItemApp from 'ee/admin/data_management_item/components/app.vue';

describe('AdminDataManagementItemApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementItemApp);
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    createComponent();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe('Data management');
  });
});
