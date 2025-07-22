import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ValidityCheckRefresh from 'ee/vulnerabilities/components/validity_check_refresh.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

describe('ValidityCheckRefresh', () => {
  let wrapper;

  const defaultProps = {
    findingTokenStatus: {
      status: 'ACTIVE',
      updatedAt: '2023-01-01T00:00:00Z',
    },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ValidityCheckRefresh, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findLastCheckedTimestamp = () => wrapper.findByTestId('validity-last-checked');
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findRetryButton = () => wrapper.findComponent(GlButton);

  describe('when findingTokenStatus has updatedAt', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays the correct text', () => {
      expect(findLastCheckedTimestamp().text()).toContain('Last checked:');
    });

    it('does not display the "not available" text', () => {
      expect(findLastCheckedTimestamp().text()).not.toContain('not available');
    });

    it('renders TimeAgoTooltip with the updatedAt value', () => {
      expect(findTimeAgoTooltip().props('time')).toBe(defaultProps.findingTokenStatus.updatedAt);
    });
  });

  describe('when findingTokenStatus is null', () => {
    beforeEach(() => {
      createWrapper({ findingTokenStatus: null });
    });

    it('displays the unavailable text', () => {
      expect(findLastCheckedTimestamp().text()).toMatchInterpolatedText(
        'Last checked: not available',
      );
    });

    it('does not render TimeAgoTooltip', () => {
      expect(findTimeAgoTooltip().exists()).toBe(false);
    });
  });

  describe('retry button', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('is rendered correctly', () => {
      expect(findRetryButton().props()).toMatchObject({
        category: 'tertiary',
        size: 'small',
        icon: 'retry',
        loading: false,
      });
    });
  });
});
