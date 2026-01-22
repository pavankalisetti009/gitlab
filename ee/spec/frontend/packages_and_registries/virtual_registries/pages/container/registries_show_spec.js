import { shallowMount } from '@vue/test-utils';
import RegistriesShow from 'ee/packages_and_registries/virtual_registries/pages/container/registries_show.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('RegistriesShow', () => {
  let wrapper;

  const createComponent = () => {
    return shallowMount(RegistriesShow);
  };

  describe('rendering', () => {
    it('renders page heading', () => {
      wrapper = createComponent();
      expect(wrapper.findComponent(PageHeading).props('heading')).toBe('Show registry');
    });
  });
});
