import { shallowMount } from '@vue/test-utils';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import StatsCard from 'ee/usage_quotas/pages/components/stats.vue';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';

describe('PagesDeploymentsStats', () => {
  let wrapper;

  const deploymentsLimit = 100;
  const deploymentsCount = 50;
  const fullPath = '/path/to/project';

  const createComponent = () => {
    wrapper = shallowMount(StatsCard, {
      provide: {
        deploymentsLimit,
        deploymentsCount,
        fullPath,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders StatisticsCard component', () => {
    expect(wrapper.findComponent(StatisticsCard).exists()).toBe(true);
  });

  it('passes correct props to StatisticsCard', () => {
    const statisticsCard = wrapper.findComponent(StatisticsCard);
    expect(statisticsCard.props('usageValue')).toBe(`${deploymentsCount}`);
    expect(statisticsCard.props('totalValue')).toBe(deploymentsLimit);
    expect(statisticsCard.props('description')).toBe('Parallel deployments');
    expect(statisticsCard.props('helpLink')).toBe(
      `${DOCS_URL_IN_EE_DIR}/user/project/pages/#limits`,
    );
    expect(statisticsCard.props('helpLabel')).toBe('Learn about limits for Pages deployments');
    expect(statisticsCard.props('helpTooltip')).toBe('Learn about limits for Pages deployments');
    expect(statisticsCard.props('percentage')).toBe(50);
  });
});
