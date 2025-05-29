import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectToolCoverageIndicator from 'ee/security_inventory/components/project_tool_coverage_indicator.vue';
import { SCANNER_POPOVER_GROUPS, SCANNER_TYPES } from 'ee/security_inventory/constants';
import ToolCoverageDetails from 'ee/security_inventory/components/tool_coverage_details.vue';
import { subgroupsAndProjects } from 'ee_jest/security_inventory/mock_data';

describe('ProjectToolCoverageIndicator', () => {
  let wrapper;

  const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
  const projectName = mockProject.name;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectToolCoverageIndicator, {
      propsData: {
        item: {
          ...props,
          ...mockProject,
          analyzerStatuses: props.analyzerStatuses || mockProject.analyzerStatuses,
        },
      },
    });
  };

  const findPopover = (key) => wrapper.findByTestId(`popover-${key}-${projectName}`);
  const findToolCoverageDetails = () => wrapper.findComponent(ToolCoverageDetails);
  const findBadge = (key) => wrapper.findByTestId(`badge-${key}-${projectName}`);

  const scanners = Object.entries(SCANNER_POPOVER_GROUPS).map(([key, scannerTypes]) => ({
    key,
    scannerTypes,
    label: SCANNER_TYPES[key].textLabel,
    name: SCANNER_TYPES[key].name,
  }));

  describe('component rendering', () => {
    it('renders all scanner badges', () => {
      createComponent();

      scanners.forEach(({ key, label }) => {
        expect(findBadge(key).exists()).toBe(true);
        expect(findBadge(key).text()).toBe(label);
      });
    });

    it('renders all popovers with correct targets', () => {
      createComponent();
      scanners.forEach(({ key }) => {
        expect(findPopover(key).exists()).toBe(true);
        expect(findPopover(key).props('target')).toBe(`tool-coverage-${key}-${projectName}`);
      });
    });

    it('renders tool coverage details component in popovers', () => {
      createComponent();
      expect(findToolCoverageDetails().exists()).toBe(true);
    });
  });

  describe.each(scanners)('$label scanner', ({ scannerTypes, label, key, name }) => {
    it('shows success variant when all scanners are successful', () => {
      const successfulScanners = scannerTypes.map((type) => ({
        analyzerType: type,
        status: 'SUCCESS',
      }));
      createComponent({
        props: { analyzerStatuses: successfulScanners },
      });
      expect(findBadge(key).props('variant')).toBe('success');
      expect(findBadge(key).classes()).toContain('gl-border-transparent');
      expect(findBadge(key).text()).toBe(label);
    });

    it('shows danger variant when at least one scanner failed', () => {
      const failedScanners = scannerTypes.map((type, index) => ({
        analyzerType: type,
        status: index === 0 ? 'FAILED' : 'SUCCESS',
      }));

      createComponent({
        props: { analyzerStatuses: failedScanners },
      });
      expect(findBadge(key).props('variant')).toBe('danger');
      expect(findBadge(key).classes()).toContain('gl-border-red-600');
      expect(findBadge(key).text()).toBe(label);
    });

    it('shows disabled styling when no scanners are present', () => {
      createComponent({
        props: { analyzerStatuses: [] },
      });

      expect(findBadge(key).props('variant')).toBe('muted');
      expect(findBadge(key).classes()).toContain('gl-border-dashed');
      expect(findBadge(key).text()).toBe(label);
    });

    it('shows disabled styling when scanners exist but have no status', () => {
      const disabledScanners = scannerTypes.map((type) => ({
        analyzerType: type,
      }));

      createComponent({
        props: { analyzerStatuses: disabledScanners },
      });
      expect(findBadge(key).props('variant')).toBe('muted');
      expect(findBadge(key).classes()).toContain('gl-border-dashed');
      expect(findBadge(key).text()).toBe(label);
    });

    it('popover has correct title and properties', () => {
      createComponent();
      expect(findPopover(key).exists()).toBe(true);
      expect(findPopover(key).props('title')).toBe(name);
      expect(findPopover(key).props('target')).toBe(`tool-coverage-${key}-${projectName}`);
    });

    it('passes correct data to tool coverage details component', () => {
      const testScanners = scannerTypes.map((type) => ({
        analyzerType: type,
      }));
      createComponent({
        props: { analyzerStatuses: testScanners },
      });
      expect(findToolCoverageDetails().props('isProject')).toBe(true);
    });
  });

  describe('getRelevantScannerData method', () => {
    it('returns existing statuses when available', () => {
      const testScanners = [
        { analyzerType: 'SAST', status: 'SUCCESS' },
        { analyzerType: 'DAST', status: 'FAILED' },
      ];

      createComponent({
        props: { analyzerStatuses: testScanners },
      });
      const result = wrapper.vm.getRelevantScannerData(['SAST', 'DAST']);
      expect(result).toEqual([
        { analyzerType: 'SAST', status: 'SUCCESS' },
        { analyzerType: 'DAST', status: 'FAILED' },
      ]);
    });

    it('returns analyzer type only when status is not available', () => {
      createComponent({
        props: { analyzerStatuses: [] },
      });
      const result = wrapper.vm.getRelevantScannerData(['SAST', 'DAST']);
      expect(result).toEqual([{ analyzerType: 'SAST' }, { analyzerType: 'DAST' }]);
    });

    it('returns mixed results for partial matches', () => {
      const testScanners = [{ analyzerType: 'SAST', status: 'SUCCESS' }];

      createComponent({
        props: { analyzerStatuses: testScanners },
      });
      const result = wrapper.vm.getRelevantScannerData(['SAST', 'DAST']);
      expect(result).toEqual([
        { analyzerType: 'SAST', status: 'SUCCESS' },
        { analyzerType: 'DAST' },
      ]);
    });
  });
});
