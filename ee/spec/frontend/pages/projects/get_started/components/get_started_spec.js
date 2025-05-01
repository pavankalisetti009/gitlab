import { shallowMount } from '@vue/test-utils';
import GetStarted from 'ee/pages/projects/get_started/components/get_started.vue';

describe('GetStarted component', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(GetStarted);
  });

  describe('rendering', () => {
    it('renders correctly', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });
});
