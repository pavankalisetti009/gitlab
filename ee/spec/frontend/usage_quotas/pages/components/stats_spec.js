import { GlLink } from '@gitlab/ui';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import StatsCard from 'ee/usage_quotas/pages/components/stats.vue';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('PagesDeploymentsStats', () => {
  let wrapper;

  const deploymentsLimit = 100;
  const deploymentsCount = 50;
  const fullPath = '/path/to/project';

  const createComponent = () => {
    wrapper = shallowMountExtended(StatsCard, {
      propsData: {
        title: 'Pages Deployments',
      },
      provide: {
        deploymentsLimit,
        deploymentsCount,
        fullPath,
        deploymentsByProject: [
          {
            name: 'Project 1',
            count: 35,
          },
          {
            name: 'Project 2',
            count: 15,
          },
        ],
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders SectionedPercentageBar component', () => {
    expect(wrapper.findComponent(SectionedPercentageBar).exists()).toBe(true);
  });

  it('passes the expected sections to SectionedPercentageBar', () => {
    const percentageBar = wrapper.findComponent(SectionedPercentageBar);
    expect(percentageBar.props('sections')).toEqual([
      {
        id: 0,
        label: 'Project 1',
        value: 35,
        formattedValue: '35',
      },
      {
        id: 1,
        label: 'Project 2',
        value: 15,
        formattedValue: '15',
      },
      {
        id: 'free',
        label: 'Remaining deployments',
        color: 'var(--gray-50)',
        value: 50,
        formattedValue: 50,
        hideLabel: true,
      },
    ]);
  });

  it('displays the title', () => {
    expect(wrapper.find('h2').text()).toEqual('Pages Deployments');
  });

  it('displays the count', () => {
    expect(wrapper.findByTestId('count').text()).toEqual('50 / 100');
  });

  it('displays the description', () => {
    expect(wrapper.text()).toContain('Active parallel deployments');
  });

  it('displays the help link', () => {
    const link = wrapper.getComponent(GlLink);

    expect(link.attributes('href')).toBe(`${DOCS_URL_IN_EE_DIR}/user/project/pages/#limits`);
    expect(link.attributes('title')).toBe('Learn about limits for Pages deployments');
    expect(link.attributes('aria-label')).toBe('Learn about limits for Pages deployments');
  });
});
