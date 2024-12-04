import { GlModal, GlTableLite } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import DenyAllowListModal from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_modal.vue';
import DenyAllowLicenses from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_licenses.vue';
import DenyAllowExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_exceptions.vue';

describe('DenyAllowListModal', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowListModal, {
      propsData,
      provide: {
        parsedSoftwareLicenses: [],
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
        GlTableLite: stubComponent(GlTableLite, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findLicenses = () => wrapper.findAllComponents(DenyAllowLicenses);
  const findExceptions = () => wrapper.findAllComponents(DenyAllowExceptions);

  describe('default rendering', () => {
    it('renders table with one selected row', () => {
      createComponent();

      expect(findTable().exists()).toBe(true);
      expect(findLicenses()).toHaveLength(1);
      expect(findExceptions()).toHaveLength(1);

      expect(findModal().props('title')).toBe('Edit denylist');
      expect(findModal().props('actionPrimary').text).toBe('Save denylist');
    });
  });
});
