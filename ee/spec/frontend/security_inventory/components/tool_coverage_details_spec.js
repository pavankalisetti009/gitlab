import { GlButton, GlIcon } from '@gitlab/ui';
import ToolCoverageDetails from 'ee/security_inventory/components/tool_coverage_details.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ToolCoverageDetails', () => {
  let wrapper;

  const emptyAnalyzerStatus = [
    {
      analyzerType: 'SAST_IAC',
    },
  ];

  const singleAnalyzerStatus = [
    {
      analyzerType: 'DEPENDENCY_SCANNING',
      status: 'SUCCESS',
    },
  ];

  const multipleAnalyzerStatuses = [
    {
      analyzerType: 'SAST',
      status: 'SUCCESS',
    },
    {
      analyzerType: 'SAST_ADVANCED',
      status: 'SUCCESS',
    },
  ];

  const failedAnalyzerStatuses = [
    {
      analyzerType: 'SAST',
      status: 'FAILED',
    },
    {
      analyzerType: 'SAST_ADVANCED',
      status: 'SUCCESS',
    },
  ];

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ToolCoverageDetails, {
      propsData: {
        securityScanner: multipleAnalyzerStatuses,
        isProject: true,
        ...propsData,
      },
    });
  };

  const findAllGlIcons = () => wrapper.findAllComponents(GlIcon);
  const findGlIcon = () => wrapper.findComponent(GlIcon);
  const findByTestId = (id) => wrapper.findByTestId(id);
  const findButton = () => wrapper.findComponent(GlButton);

  describe('single scanner type', () => {
    it('renders the correct status label when the scanner is enabled', () => {
      createComponent({ securityScanner: singleAnalyzerStatus });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Enabled');
    });

    it('renders the correct status label when the scanner is disabled', () => {
      createComponent({
        securityScanner: [{ analyzerType: 'DEPENDENCY_SCANNING', status: 'DISABLED' }],
      });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Not enabled');
    });
  });

  describe('multiple scanners types', () => {
    it('renders multiple status labels when the scanners are enabled', () => {
      createComponent({ securityScanner: multipleAnalyzerStatuses });

      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Enabled');
      });
    });

    it('renders multiple status labels when the scanners are not enabled', () => {
      createComponent({
        securityScanner: [{ analyzerType: 'SAST' }, { analyzerType: 'SAST_ADVANCED' }],
      });
      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Not enabled');
      });
    });

    it('renders mixed status labels when some scanners are enabled and some failed', () => {
      createComponent({ securityScanner: failedAnalyzerStatuses });
      expect(findByTestId('scanner-title-0').text()).toEqual('Basic SAST:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Failed');
      expect(findByTestId('scanner-title-1').text()).toEqual('GitLab Advanced SAST:');
      expect(findByTestId('scanner-status-1').text()).toEqual('Enabled');
    });
  });

  describe('empty security scanner', () => {
    it('renders default status when no security scanner data is provided', () => {
      createComponent({ securityScanner: emptyAnalyzerStatus });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Not enabled');
    });
  });

  describe('icons', () => {
    it('displays correct icon for enabled status', () => {
      createComponent({ securityScanner: singleAnalyzerStatus });
      expect(findGlIcon().exists()).toBe(true);
      expect(findGlIcon().props('name')).toBe('check-circle-filled');
      expect(findGlIcon().props('variant')).toBe('success');
    });

    it('displays correct icon for failed status', () => {
      createComponent({
        securityScanner: [{ analyzerType: 'SAST', status: 'FAILED' }],
      });
      expect(findGlIcon().exists()).toBe(true);
      expect(findGlIcon().props('name')).toBe('status-failed');
      expect(findGlIcon().props('variant')).toBe('danger');
    });

    it('displays correct icon for disabled status', () => {
      createComponent({ securityScanner: emptyAnalyzerStatus });
      expect(findGlIcon().exists()).toBe(true);
      expect(findGlIcon().props('name')).toBe('clear');
      expect(findGlIcon().props('variant')).toBe('disabled');
    });

    it('displays correct number of icons for multiple scanners', () => {
      createComponent({ securityScanner: multipleAnalyzerStatuses });
      expect(findAllGlIcons()).toHaveLength(2);
    });
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

  describe('manage configuration button', () => {
    it('renders "Manage configuration" button when "isProject" is true', () => {
      createComponent();
      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toBe('Manage configuration');
      // TODO: to expose when we got the relevant data from the API
      // expect(findButton().attributes('href')).toBe(`${webUrl}/-/security/configuration`);
      expect(findButton().props('category')).toBe('secondary');
      expect(findButton().props('variant')).toBe('confirm');
      expect(findButton().props('size')).toBe('small');
    });

    it('does not render "Manage configuration" button when isProject is false', () => {
      createComponent({ isProject: false });
      expect(findButton().exists()).toBe(false);
    });
  });
});
