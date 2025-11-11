import { GlTabs, GlLink } from '@gitlab/ui';
import { merge } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CiCdAnalyticsApp from 'ee/analytics/group_ci_cd_analytics/components/app.vue';
import ReleaseStatsCard from 'ee/analytics/group_ci_cd_analytics/components/release_stats_card.vue';
import MigrationAlert from 'ee_component/analytics/dora/components/migration_alert.vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { getParameterValues } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility');

describe('ee/analytics/group_ci_cd_analytics/components/app.vue', () => {
  let wrapper;

  beforeEach(() => {
    getParameterValues.mockReturnValue([]);
  });

  const groupPath = 'funkys/flightjs';
  const quotaPath = '/groups/my-awesome-group/-/usage_quotas#pipelines-quota-tab';

  const createComponent = (mountOptions = {}, canView = true) => {
    wrapper = shallowMountExtended(
      CiCdAnalyticsApp,
      merge(
        {
          provide: {
            groupPath,
            pipelineGroupUsageQuotaPath: quotaPath,
            canViewGroupUsageQuotaBoolean: canView,
          },
        },
        mountOptions,
      ),
    );
  };

  const findGlTabs = () => wrapper.findComponent(GlTabs);
  const findUsageQuotaLink = () => wrapper.findComponent(GlLink);
  const findDoraMetricsMigrationAlert = () => wrapper.findComponent(MigrationAlert);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the release statistics component', () => {
      expect(wrapper.findComponent(ReleaseStatsCard).exists()).toBe(true);
    });

    it('shows migration alert', () => {
      expect(findDoraMetricsMigrationAlert().props().namespacePath).toBe(groupPath);
    });
  });

  describe('when provided with a query param', () => {
    it.each`
      tab                     | index
      ${'release-statistics'} | ${'0'}
      ${'fake'}               | ${'0'}
      ${''}                   | ${'0'}
    `('shows the correct tab for URL parameter "$tab"', ({ tab, index }) => {
      setWindowLocation(`${TEST_HOST}/groups/gitlab-org/gitlab/-/analytics/ci_cd?tab=${tab}`);
      getParameterValues.mockImplementation((name) => {
        expect(name).toBe('tab');
        return tab ? [tab] : [];
      });
      createComponent();
      expect(findGlTabs().attributes('value')).toBe(index);
    });
  });

  it('displays link to group pipeline usage quota page', () => {
    createComponent({
      stubs: {
        GlTabs: {
          template: '<div><slot></slot><slot name="tabs-end"></slot></div>',
        },
      },
    });

    expect(findUsageQuotaLink().attributes('href')).toBe(quotaPath);
    expect(findUsageQuotaLink().text()).toBe('View group pipeline usage quota');
  });

  it('hides link to group pipelines usage quota page based on permissions', () => {
    createComponent(
      {
        stubs: {
          GlTabs: {
            template: '<div><slot></slot><slot name="tabs-end"></slot></div>',
          },
        },
      },
      false,
    );

    expect(findUsageQuotaLink().exists()).toBe(false);
  });
});
