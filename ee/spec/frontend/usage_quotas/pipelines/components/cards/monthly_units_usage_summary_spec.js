import { GlProgressBar } from '@gitlab/ui';
import MonthlyUnitsUsageSummary from 'ee_else_ce/usage_quotas/pipelines/components/cards/monthly_units_usage_summary.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { formatDate } from '~/lib/utils/datetime_utility';
import { defaultProvide } from '../../mock_data';

describe('MonthlyUnitsUsageSummary', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    monthlyUnitsUsed: defaultProvide.ciMinutesMonthlyMinutesUsed,
    monthlyUnitsLimit: defaultProvide.ciMinutesMonthlyMinutesLimit,
    monthlyUnitsUsedPercentage: defaultProvide.ciMinutesMonthlyMinutesUsedPercentage,
    lastResetDate: defaultProvide.ciMinutesLastResetDate,
    anyProjectEnabled: defaultProvide.ciMinutesAnyProjectEnabled,
    displayMinutesAvailableData: defaultProvide.ciMinutesDisplayMinutesAvailableData,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(MonthlyUnitsUsageSummary, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findMinutesTitle = () => wrapper.findByTestId('minutes-title');
  const findMinutesUsed = () => wrapper.findByTestId('minutes-used');
  const findMinutesUsedPercentage = () => wrapper.findByTestId('minutes-used-percentage');
  const findGlProgressBar = () => wrapper.findComponent(GlProgressBar);

  beforeEach(() => {
    createComponent();
  });

  it('renders the minutes title properly', () => {
    expect(findMinutesTitle().text()).toBe(
      `Compute usage since ${formatDate(defaultProps.lastResetDate, 'mmm dd, yyyy', true)}`,
    );
  });

  it('renders the minutes used properly', () => {
    expect(findMinutesUsed().text()).toBe(
      `${defaultProps.monthlyUnitsUsed} / ${defaultProps.monthlyUnitsLimit} units`,
    );
  });

  it('renders the minutes used percentage properly', () => {
    expect(findMinutesUsedPercentage().text()).toBe(
      `${defaultProps.monthlyUnitsUsedPercentage}% used`,
    );
  });

  it('passess the correct props to GlProgressBar', () => {
    expect(findGlProgressBar().attributes()).toMatchObject({
      value: defaultProps.monthlyUnitsUsedPercentage,
    });
  });

  it('shows unlimited as usage percentage if quotas are disabled', () => {
    createComponent({
      props: {
        displayMinutesAvailableData: false,
        anyProjectEnabled: false,
      },
    });

    expect(findMinutesUsedPercentage().text()).toBe('Unlimited');
  });
});
