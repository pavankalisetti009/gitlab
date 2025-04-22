import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import { SCANNER_POPOVER_GROUPS, SCANNER_TYPES } from 'ee/security_inventory/constants';
import toolCoverageDetails from 'ee/security_inventory/components/tool_coverage_details.vue';

describe('ProjectToolCoverageIndicator', () => {
  let wrapper;

  const projectName = 'my-project';

  const createComponent = ({ props = {} } = {}) => {
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

  const scanners = Object.entries(SCANNER_POPOVER_GROUPS).map(([key, scannerTypes]) => ({
    key,
    scannerTypes,
    label: SCANNER_TYPES[key].textLabel,
  }));

  describe.each(scanners)('$scanner badge', ({ scannerTypes, label, key }) => {
    it('shows success variant when enabled', () => {
      createComponent({
        props: { securityScanners: { enabled: scannerTypes, pipelineRun: scannerTypes } },
      });

      expect(findByTestId(`badge-${key}-${projectName}`).props('variant')).toBe('success');
      expect(findByTestId(`badge-${key}-${projectName}`).text()).toBe(label);
    });

    it('shows danger variant with border when failed', () => {
      createComponent({ props: { securityScanners: { enabled: scannerTypes } } });

      expect(findByTestId(`badge-${key}-${projectName}`).props('variant')).toBe('danger');
      expect(findByTestId(`badge-${key}-${projectName}`).classes()).toContain('gl-border-red-600');
      expect(findByTestId(`badge-${key}-${projectName}`).text()).toBe(label);
    });

    it('shows dashed outline for $scanner when disabled', () => {
      createComponent({ props: { enabledScanners: [] } });

      expect(findByTestId(`badge-${key}-${projectName}`).classes()).toContain('gl-border-dashed');
      expect(findByTestId(`badge-${key}-${projectName}`).text()).toBe(label);
    });

    it('render current values of popover', () => {
      createComponent();
      expect(findPopover().exists()).toBe(true);
      expect(findToolCoverageDetails().exists()).toBe(true);
      expect(findByTestId(`popover-${key}-${projectName}`).props('target')).toBe(
        `tool-coverage-${key}-${projectName}`,
      );
    });
  });
});
