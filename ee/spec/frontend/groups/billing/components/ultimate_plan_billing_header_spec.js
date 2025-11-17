import { GlBadge, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import UltimatePlanBillingHeader from 'ee/groups/billing/components/ultimate_plan_billing_header.vue';
import { TEST_HOST } from 'helpers/test_constants';
import axios from '~/lib/utils/axios_utils';
import { mockBillingPageAttributes } from '../../mock_data';

jest.mock('~/lib/utils/axios_utils');

describe('UltimatePlanBillingHeader', () => {
  let wrapper;

  const ctaLabel = '__ctaLabel__';
  const trackingUrl = `${TEST_HOST}/track`;
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findGlButton = () => wrapper.findComponent(GlButton);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(UltimatePlanBillingHeader, {
      propsData: { ...mockBillingPageAttributes, ...props, ctaLabel, trackingUrl },
    });
  };

  beforeEach(() => {
    axios.post = jest.fn();
  });

  it('renders badge', () => {
    createComponent();

    const cta = findGlButton();

    expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToUltimateUrl);
    expect(cta.text()).toBe(ctaLabel);
    expect(findGlBadge().exists()).toBe(false);
  });

  it('calls tracking API when button is clicked', () => {
    axios.post.mockResolvedValue({});
    createComponent();

    findGlButton().vm.$emit('click');

    expect(axios.post).toHaveBeenCalledWith(trackingUrl);
  });

  it('silently fails when tracking API fails', () => {
    axios.post.mockRejectedValue(new Error('Network error'));
    createComponent();

    expect(() => findGlButton().vm.$emit('click')).not.toThrow();
    expect(axios.post).toHaveBeenCalledWith(trackingUrl);
  });

  describe('when trial is active', () => {
    it('does not render badge', () => {
      createComponent({ trialActive: true });

      expect(findGlBadge().text()).toBe('Currently trialing');
    });
  });
});
