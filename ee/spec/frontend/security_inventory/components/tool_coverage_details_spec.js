import { GlButton, GlIcon } from '@gitlab/ui';
import ToolCoverageDetails from 'ee/security_inventory/components/tool_coverage_details.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ToolCoverageDetails', () => {
  let wrapper;

  const singleScanner = {
    scannerTypes: ['DEPENDENCY_SCANNING'],
    enabled: [],
    pipelineRun: [],
  };
  const multipleScanners = {
    scannerTypes: ['SAST', 'SAST_ADVANCED'],
    enabled: [],
    pipelineRun: [],
  };
  const webUrl = 'gdk.test/groups/my-project';

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ToolCoverageDetails, {
      propsData: {
        securityScanner: multipleScanners,
        isProject: true,
        webUrl,
        ...propsData,
      },
    });
  };

  const findGlIcon = () => wrapper.findComponent(GlIcon);
  const findByTestId = (id) => wrapper.findByTestId(id);
  const findButton = () => wrapper.findComponent(GlButton);

  describe('single scanner type', () => {
    it('renders the correct status label when the scanner is enabled', () => {
      createComponent({ securityScanner: { ...singleScanner, enabled: ['DEPENDENCY_SCANNING'] } });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Enabled');
    });

    it('renders the correct status label when the scanner is not enabled', () => {
      createComponent({ securityScanner: singleScanner });
      expect(findByTestId(`scanner-title-0`).text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Not enabled');
    });
  });

  describe('multiple scanners types', () => {
    it('renders multiple status labels when the scanner is enabled', () => {
      createComponent({
        securityScanner: { ...multipleScanners, enabled: ['SAST', 'SAST_ADVANCED'] },
      });
      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Enabled');
      });
    });

    it('renders multiple status labels when the scanner is not enabled', () => {
      createComponent({
        securityScanner: { ...multipleScanners, enabled: [] },
      });
      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Not enabled');
      });
    });
  });

  it('displays correct icon for enabled status', () => {
    createComponent({
      securityScanner: { ...multipleScanners, enabled: ['SAST', 'SAST_ADVANCED'] },
    });
    expect(findGlIcon().exists()).toBe(true);
    expect(findGlIcon().props('name')).toBe('check-circle-filled');
  });

  it('displays correct icon for disabled status', () => {
    createComponent();
    expect(findGlIcon().exists()).toBe(true);
    expect(findGlIcon().props('name')).toBe('clear');
  });

  // TODO: to expose when we got the relevant data from the API
  // eslint-disable-next-line jest/no-disabled-tests
  it.skip('renders "Last scan" label with placeholder when no scan exists', () => {
    createComponent();
    expect(findByTestId('last-scan').exists()).toBe(true);
    expect(findByTestId('last-scan').text()).toContain('Last scan:');
    const scanIcon = findByTestId('last-scan').findComponent(GlIcon);
    expect(scanIcon.exists()).toBe(true);
    expect(scanIcon.props('name')).toBe('dash');
  });

  it('renders "Manage configuration" button when "isProject" is true', () => {
    createComponent();
    expect(findButton().exists()).toBe(true);
    expect(findButton().text()).toBe('Manage configuration');
    // TODO: to expose when we got the relevant data from the API
    // expect(findButton().attributes('href')).toBe(`${webUrl}/-/security/configuration`);
  });

  it('does not render "Manage configuration" button when isProject is false', () => {
    createComponent({ isProject: false });
    expect(findButton().exists()).toBe(false);
  });
});
