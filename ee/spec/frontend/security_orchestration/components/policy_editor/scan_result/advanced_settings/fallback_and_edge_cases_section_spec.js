import { shallowMount } from '@vue/test-utils';
import {
  CLOSED,
  OPEN,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import FallbackAndEdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_and_edge_cases_section.vue';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_section.vue';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';
import DimDisableContainer from 'ee/security_orchestration/components/policy_editor/dim_disable_container.vue';

describe('FallbackAndEdgeCasesSection', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(FallbackAndEdgeCasesSection, {
      propsData: {
        policy: {
          fallback_behavior: { fail: CLOSED },
        },
        ...propsData,
      },
      provide,
      stubs: { DimDisableContainer },
    });
  };

  const findDimContainer = () => wrapper.findComponent(DimDisableContainer);
  const findFallbackSection = () => wrapper.findComponent(FallbackSection);
  const findEdgeCasesSection = () => wrapper.findComponent(EdgeCasesSection);

  it('enables the container by default', () => {
    createComponent();
    expect(findDimContainer().props('disabled')).toBe(false);
  });

  it('disables the selection when "disabled" is "true"', () => {
    createComponent({ propsData: { disabled: true } });
    expect(findDimContainer().props('disabled')).toBe(true);
  });

  describe('fallback section', () => {
    it('renders the fallback section with "property: closed" for a policy without fallback section', () => {
      createComponent();
      expect(findFallbackSection().props()).toEqual({
        property: CLOSED,
      });
    });

    it('renders the fallback section with "property: closed" for a policy with fallback section', () => {
      createComponent({ propsData: { policy: { fallback_behavior: { fail: OPEN } } } });
      expect(findFallbackSection().props()).toEqual({
        property: OPEN,
      });
    });
  });

  describe('policy edge cases section', () => {
    it('renders the edge cases section with FF enabled', () => {
      createComponent({
        provide: {
          glFeatures: {
            unblockRulesUsingExecutionPolicies: true,
          },
        },
      });
      expect(findEdgeCasesSection().props()).toStrictEqual({
        policyTuning: { unblock_rules_using_execution_policies: false },
      });
    });

    it('renders the edge cases section with FF enabled and policy value provided', () => {
      createComponent({
        propsData: {
          policy: { policy_tuning: { unblock_rules_using_execution_policies: true } },
        },
        provide: {
          glFeatures: {
            unblockRulesUsingExecutionPolicies: true,
          },
        },
      });
      expect(findEdgeCasesSection().props()).toEqual({
        policyTuning: { unblock_rules_using_execution_policies: true },
      });
    });

    it('does not render the edge cases section with FF disabled', () => {
      createComponent({
        provide: {
          glFeatures: {
            unblockRulesUsingExecutionPolicies: false,
          },
        },
      });
      expect(findEdgeCasesSection().exists()).toBe(false);
    });
  });
});
