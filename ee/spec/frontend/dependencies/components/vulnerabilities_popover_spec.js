import { nextTick } from 'vue';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesPopover from 'ee/dependencies/components/vulnerabilities_popover.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';

describe('VulnerabilitiesPopover component', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createWrapper = ({ shouldShowCallout = true } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(VulnerabilitiesPopover, {
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });
  };

  const findVulnerabilityInfoIcon = () => wrapper.findComponent(GlIcon);
  const findVulnerabilityInfoPopover = () => wrapper.findByTestId('vulnerability-info-popover');

  beforeEach(createWrapper);

  it('renders vulnerability info icon and popover', () => {
    expect(findVulnerabilityInfoIcon().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().props()).toMatchObject({
      title: 'Focused vulnerability reporting',
      show: true,
    });
    expect(findVulnerabilityInfoPopover().text()).toBe(
      'The dependency list shows only active, currently detected issues. Vulnerabilities that are no longer detected are filtered out.',
    );
  });

  describe('when popover has been dismissed', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: false });
    });

    it('does not show popover', () => {
      expect(findVulnerabilityInfoPopover().props('show')).toBe(false);
    });
  });

  describe('when popover is dismissed', () => {
    it('handles closing the feature pop-up', async () => {
      findVulnerabilityInfoPopover().vm.$emit('close-button-clicked');
      await nextTick();
      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });
});
