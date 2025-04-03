import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import { SCANNERS } from 'ee/security_inventory/constants';
import toolCoverageDetails from 'ee/security_inventory/components/tool_coverage_details.vue';

describe('ProjectToolCoverageIndicator', () => {
  let wrapper;

  const projectName = 'my-project';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ProjectToolCoverageIndicator, {
      propsData: {
        projectName,
        ...props,
      },
    });
  };

  const findPopover = () => wrapper.findComponent(GlPopover);
  const findToolCoverageDetails = () => wrapper.findComponent(toolCoverageDetails);
  const findByTestId = (id) => wrapper.findByTestId(id);

  describe.each(SCANNERS)('$scanner badge', ({ scanner, label }) => {
    it('shows success variant when enabled', () => {
      createComponent({
        securityScanners: { enabled: [scanner], pipelineRun: [scanner] },
      });

      expect(findByTestId(`badge-${label}-${projectName}`).props('variant')).toBe('success');
      expect(findByTestId(`badge-${label}-${projectName}`).text()).toBe(label);
    });

    it('shows danger variant with border when failed', () => {
      createComponent({ securityScanners: { enabled: [scanner] } });

      expect(findByTestId(`badge-${label}-${projectName}`).props('variant')).toBe('danger');
      expect(findByTestId(`badge-${label}-${projectName}`).classes()).toContain(
        'gl-border-red-600',
      );
      expect(findByTestId(`badge-${label}-${projectName}`).text()).toBe(label);
    });

    it('shows dashed outline for $scanner when disabled', () => {
      createComponent({ enabledScanners: [] });

      expect(findByTestId(`badge-${label}-${projectName}`).classes()).toContain('gl-border-dashed');
      expect(findByTestId(`badge-${label}-${projectName}`).text()).toBe(label);
    });

    it('render current values of popover', () => {
      createComponent();
      expect(findPopover().exists()).toBe(true);
      expect(findToolCoverageDetails().exists()).toBe(true);
      expect(findByTestId(`popover-${label}-${projectName}`).props('target')).toBe(
        `tool-coverage-${label}-${projectName}`,
      );
    });
  });
});
