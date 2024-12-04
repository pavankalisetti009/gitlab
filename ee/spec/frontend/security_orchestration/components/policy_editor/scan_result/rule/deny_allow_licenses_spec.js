import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DenyAllowLicenses from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_licenses.vue';
import { UNKNOWN_LICENSE } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('DenyAllowLicenses', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowLicenses, {
      propsData,
      provide: {
        parsedSoftwareLicenses: [],
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering', () => {
    it('renders default list with unknown license', () => {
      createComponent();

      expect(findListBox().props('items')).toEqual([
        { options: [UNKNOWN_LICENSE], text: 'Licenses' },
      ]);
      expect(findListBox().props('toggleText')).toBe('Choose a license');
    });

    it('selects a license', () => {
      createComponent();

      findListBox().vm.$emit('select', UNKNOWN_LICENSE.value);

      expect(wrapper.emitted('select')).toEqual([[UNKNOWN_LICENSE]]);
    });

    it('renders selected license', () => {
      createComponent({
        propsData: { selected: { value: 'license', text: 'License' } },
      });

      expect(findListBox().props('selected')).toEqual('license');
    });
  });
});
