import { shallowMount } from '@vue/test-utils';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('AdminDataManagementApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementApp);
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    createComponent();
  });

  it('renders page heading', () => {
    expect(findPageHeading().text()).toBe('Data management');
  });
});
