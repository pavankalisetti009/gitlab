import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesPopover from 'ee/dependencies/components/vulnerabilities_popover.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';

describe('VulnerabilitiesPopover component', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createWrapper = ({ propsData, shouldShowCallout = true } = {}) =>
    shallowMountExtended(VulnerabilitiesPopover, {
      propsData: {
        popoverDismissed: false,
        ...propsData,
      },
      mocks: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
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
    expect(findVulnerabilityInfoPopover().props('title')).toBe('Focused vulnerability reporting');
    expect(findVulnerabilityInfoPopover().text()).toBe(
      'The dependency list shows only active, currently detected issues. Vulnerabilities that are no longer detected are filtered out.',
    );
  });

  it('shows popover and dismiss button', () => {
    expect(findVulnerabilityInfoPopover().props('show')).toBe(true);
    expect(findDismissButton().exists()).toBe(true);
  });

  describe('when popover has been dismissed', () => {
    beforeEach(() => {
      wrapper = createWrapper({ shouldShowCallout: false });
    });

    it('does not show popover or dismiss button', () => {
      expect(findVulnerabilityInfoPopover().props('show')).toBe(false);
      expect(findDismissButton().exists()).toBe(false);
    });
  });
});
