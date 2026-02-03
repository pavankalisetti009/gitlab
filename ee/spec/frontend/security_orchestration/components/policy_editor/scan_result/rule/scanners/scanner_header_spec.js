import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';

describe('ScannerHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ScannerHeader, {
      propsData: {
        title: 'Test Scanner Rule',
        visible: true,
        ...props,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findTitle = () => wrapper.find('h5');

  describe('rendering', () => {
    it('renders the title', () => {
      createComponent();

      expect(findTitle().text()).toBe('Test Scanner Rule');
    });

    it('renders the collapse button', () => {
      createComponent();

      expect(findButton().exists()).toBe(true);
    });
  });

  describe('collapse icon', () => {
    it('shows chevron-up icon when visible is true', () => {
      createComponent({ visible: true });

      expect(findButton().props('icon')).toBe('chevron-up');
    });

    it('shows chevron-down icon when visible is false', () => {
      createComponent({ visible: false });

      expect(findButton().props('icon')).toBe('chevron-down');
    });
  });

  describe('margin class', () => {
    it('adds bottom margin when visible is true', () => {
      createComponent({ visible: true });

      expect(wrapper.find('div').classes()).toContain('gl-mb-3');
    });

    it('does not add bottom margin when visible is false', () => {
      createComponent({ visible: false });

      expect(wrapper.find('div').classes()).not.toContain('gl-mb-3');
    });
  });

  describe('events', () => {
    it('emits toggle event when button is clicked', () => {
      createComponent();

      findButton().vm.$emit('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });
  });
});
