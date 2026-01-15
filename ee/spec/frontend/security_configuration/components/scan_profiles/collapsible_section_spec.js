import { GlButton, GlCollapse, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CollapsibleSection from 'ee/security_configuration/components/scan_profiles/collapsible_section.vue';

describe('CollapsibleSection', () => {
  let wrapper;

  const defaultProps = {
    title: 'Section Title',
  };

  const createComponent = ({ props = {}, slots = {} } = {}) => {
    wrapper = shallowMountExtended(CollapsibleSection, {
      propsData: { ...defaultProps, ...props },
      slots,
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findSubtitle = () => wrapper.find('p');

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders title', () => {
      expect(findButton().text()).toContain('Section Title');
    });

    it('renders chevron icon', () => {
      expect(findIcon().props('name')).toBe('chevron-right');
    });

    it('renders collapse component', () => {
      expect(findCollapse().exists()).toBe(true);
    });

    it('does not render subtitle when not provided', () => {
      expect(findSubtitle().exists()).toBe(false);
    });
  });

  describe('with subtitle', () => {
    beforeEach(() => {
      createComponent({ props: { subtitle: 'This is a subtitle' } });
    });

    it('renders subtitle', () => {
      expect(findSubtitle().text()).toBe('This is a subtitle');
    });
  });

  describe('with slot content', () => {
    beforeEach(() => {
      createComponent({ slots: { default: '<div class="test-content">Slot content</div>' } });
    });

    it('renders slot content', () => {
      expect(wrapper.text()).toContain('Slot content');
    });
  });
});
