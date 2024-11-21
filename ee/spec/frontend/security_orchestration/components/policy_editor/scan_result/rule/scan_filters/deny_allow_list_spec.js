import { GlCollapsibleListbox, GlButton, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DenyAllowList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/deny_allow_list.vue';
import {
  DENIED,
  ALLOWED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('DenyAllowList', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(DenyAllowList, {
      propsData: props,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findTypeDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findButton = () => wrapper.findComponent(GlButton);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders deny list by default', () => {
      expect(findTypeDropdown().props('selected')).toBe(DENIED);
      expect(findTypeDropdown().props('toggleText')).toBe('Denied');
      expect(findButton().text()).toBe('denylist (0 licenses)');
    });

    it('emits select type event', () => {
      findTypeDropdown().vm.$emit('select', ALLOWED);

      expect(wrapper.emitted('select-type')).toEqual([[ALLOWED]]);
    });
  });

  describe('single licence', () => {
    it('renders allowlist with single licence', () => {
      createComponent({
        props: {
          selected: ALLOWED,
          licences: ['package-1'],
        },
      });

      expect(findTypeDropdown().props('selected')).toBe(ALLOWED);
      expect(findTypeDropdown().props('toggleText')).toBe('Allowed');
      expect(findButton().text()).toBe('allowlist (1 licence)');
    });
  });

  describe('multiple licences', () => {
    it('renders denylist with multiple licences', () => {
      createComponent({
        props: {
          licences: ['package-1', 'package-2'],
        },
      });

      expect(findTypeDropdown().props('selected')).toBe(DENIED);
      expect(findTypeDropdown().props('toggleText')).toBe('Denied');
      expect(findButton().text()).toBe('denylist (2 licenses)');
    });
  });
});
