import { shallowMount } from '@vue/test-utils';
import RegistriesEdit from 'ee/packages_and_registries/virtual_registries/pages/container/registries_edit.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('RegistriesEdit', () => {
  let wrapper;

  const createComponent = () => {
    return shallowMount(RegistriesEdit);
  };

  describe('rendering', () => {
    it('renders page heading', () => {
      wrapper = createComponent();
      expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Edit registry');
    });
  });
});
