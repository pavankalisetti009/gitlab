import { GlProgressBar } from '@gitlab/ui';
import AdditionalUnitsUsageSummary from 'ee_else_ce/usage_quotas/pipelines/components/cards/additional_units_usage_summary.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { defaultProvide } from '../../mock_data';

describe('AdditionalUnitsUsageSummary', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    additionalUnitsUsed: defaultProvide.ciMinutesPurchasedMinutesUsed,
    additionalUnitsLimit: defaultProvide.ciMinutesPurchasedMinutesLimit,
    additionalUnitsUsedPercentage: defaultProvide.ciMinutesPurchasedMinutesUsedPercentage,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AdditionalUnitsUsageSummary, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findMinutesUsed = () => wrapper.findByTestId('minutes-used');
  const findMinutesUsedPercentage = () => wrapper.findByTestId('minutes-used-percentage');
  const findGlProgressBar = () => wrapper.findComponent(GlProgressBar);

  beforeEach(() => {
    createComponent();
  });

  it('renders the minutes used properly', () => {
    expect(findMinutesUsed().text()).toBe(
      `${defaultProps.additionalUnitsUsed} / ${defaultProps.additionalUnitsLimit} units`,
    );
  });

  it('renders the minutes used percentage properly', () => {
    expect(findMinutesUsedPercentage().text()).toBe(
      `${defaultProps.additionalUnitsUsedPercentage}% used`,
    );
  });

  it('passess the correct props to GlProgressBar', () => {
    expect(findGlProgressBar().attributes()).toMatchObject({
      value: defaultProps.additionalUnitsUsedPercentage,
    });
  });
});
