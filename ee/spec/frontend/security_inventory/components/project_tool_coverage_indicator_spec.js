import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import { SCANNERS } from 'ee/security_inventory/constants';

describe('ProjectToolCoverageIndicator', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(ProjectToolCoverageIndicator, { propsData });
  };

  describe.each(SCANNERS)('$scanner badge', ({ scanner, label }) => {
    it('shows success variant when enabled', () => {
      createComponent({ securityScanners: { enabled: [scanner], pipelineRun: [scanner] } });

      expect(wrapper.findByTestId(`${scanner}-badge`).props('variant')).toBe('success');
      expect(wrapper.findByTestId(`${scanner}-badge`).text()).toBe(label);
    });

    it('shows danger variant with border when failed', () => {
      createComponent({ securityScanners: { enabled: [scanner] } });

      expect(wrapper.findByTestId(`${scanner}-badge`).props('variant')).toBe('danger');
      expect(wrapper.findByTestId(`${scanner}-badge`).classes()).toContain('gl-border-red-600');
      expect(wrapper.findByTestId(`${scanner}-badge`).text()).toBe(label);
    });

    it('shows dashed outline for $scanner when disabled', () => {
      createComponent({ enabledScanners: [] });

      expect(wrapper.findByTestId(`${scanner}-badge`).classes()).toContain('gl-border-dashed');
      expect(wrapper.findByTestId(`${scanner}-badge`).text()).toBe(label);
    });
  });
});
