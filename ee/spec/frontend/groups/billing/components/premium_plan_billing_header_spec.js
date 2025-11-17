import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PremiumPlanBillingHeader from 'ee/groups/billing/components/premium_plan_billing_header.vue';
import { TEST_HOST } from 'helpers/test_constants';
import axios from '~/lib/utils/axios_utils';
import { mockBillingPageAttributes } from '../../mock_data';

jest.mock('~/lib/utils/axios_utils');

describe('PremiumPlanBillingHeader', () => {
  let wrapper;

  const ctaLabel = '__ctaLabel__';
  const trackingUrl = `${TEST_HOST}/track`;
  const findGlButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMount(PremiumPlanBillingHeader, {
      propsData: { ...mockBillingPageAttributes, ctaLabel, trackingUrl },
    });
  };

  beforeEach(() => {
    axios.post = jest.fn();
  });

  it('renders component', () => {
    createComponent();

    const cta = findGlButton();

    expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
    expect(cta.text()).toBe(ctaLabel);
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
});
