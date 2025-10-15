import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesPopover from 'ee/dependencies/components/vulnerabilities_popover.vue';
import { DEPENDENCIES_TABLE_I18N } from 'ee/dependencies/constants';

describe('VulnerabilitiesPopover component', () => {
  let wrapper;

  const createWrapper = ({ propsData } = {}) =>
    shallowMountExtended(VulnerabilitiesPopover, {
      propsData: {
        popoverDismissed: false,
        ...propsData,
      },
    });

  const findVulnerabilityInfoIcon = () => wrapper.find('#vulnerabilities-info');
  const findVulnerabilityInfoPopover = () => wrapper.findByTestId('vulnerability-info-popover');
  const findDismissButton = () => wrapper.findByTestId('dismiss-button');

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('renders vulnerability info icon and popover', () => {
    expect(findVulnerabilityInfoIcon().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().props('title')).toBe(
      DEPENDENCIES_TABLE_I18N.vulnerabilityInfoTitle,
    );
    expect(findVulnerabilityInfoPopover().text()).toContain(
      DEPENDENCIES_TABLE_I18N.vulnerabilityInfoBody,
    );
  });

  it('shows popover and dismiss button', () => {
    expect(findVulnerabilityInfoPopover().props('show')).toBe(true);
    expect(findDismissButton().exists()).toBe(true);
  });

  describe('when popover has been dismissed', () => {
    beforeEach(() => {
      wrapper = createWrapper({ popoverDismissed: true });
    });

    it('does not show popover or dismiss button', () => {
      expect(findVulnerabilityInfoPopover().props('show')).toBe(false);
      expect(findDismissButton().exists()).toBe(false);
    });
  });
});
