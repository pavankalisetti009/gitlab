import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import ValidityCheck from 'ee/vulnerabilities/components/validity_check.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import refreshFindingTokenStatusMutation from 'ee/vulnerabilities/graphql/mutations/refresh_finding_token_status.mutation.graphql';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('ValidityCheck', () => {
  let wrapper;

  const defaultProps = {
    findingTokenStatus: {
      status: 'ACTIVE',
      updatedAt: '2023-01-01T00:00:00Z',
    },
    vulnerabilityId: 123,
  };

  const createWrapper = (props = {}, { apolloProvider, validityRefresh = true } = {}) => {
    wrapper = shallowMountExtended(ValidityCheck, {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glFeatures: {
          validityRefresh,
        },
      },
    });
  };

  const findLastCheckedTimestamp = () => wrapper.findByTestId('validity-last-checked');
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findRetryButton = () => wrapper.findComponent(GlButton);
  const findTokenValidityBadge = () => wrapper.findComponent(TokenValidityBadge);

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

  describe('when user clicks retry button', () => {
    const createWrapperWithApollo = ({ props = {}, mutationHandler } = {}) => {
      const apolloProvider = createMockApollo([
        [refreshFindingTokenStatusMutation, mutationHandler],
      ]);

      createWrapper(props, { apolloProvider });
    };

    const successResponse = {
      data: {
        refreshFindingTokenStatus: {
          errors: [],
          findingTokenStatus: {
            id: 'gid://gitlab/Vulnerability/123',
            status: 'INACTIVE',
            createdAt: '2023-01-01T00:00:00Z',
            updatedAt: '2023-01-02T00:00:00Z',
          },
        },
      },
    };

    const errorResponse = {
      data: {
        refreshFindingTokenStatus: {
          errors: ['Validation failed', 'Token expired'],
          findingTokenStatus: null,
        },
      },
    };

    describe('loading', () => {
      it.each`
        scenario            | mutationHandler
        ${'success'}        | ${() => jest.fn().mockResolvedValue(successResponse)}
        ${'GraphQL errors'} | ${() => jest.fn().mockResolvedValue(errorResponse)}
        ${'exceptions'}     | ${() => jest.fn().mockRejectedValue(new Error('Network error'))}
      `('shows and clears loading state for "$scenario"', async ({ mutationHandler }) => {
        createWrapperWithApollo({ mutationHandler: mutationHandler() });

        await findRetryButton().vm.$emit('click');
        expect(findRetryButton().props('loading')).toBe(true);

        await waitForPromises();
        expect(findRetryButton().props('loading')).toBe(false);
      });
    });

    describe('with successful response', () => {
      beforeEach(() => {
        createWrapperWithApollo({
          mutationHandler: jest.fn().mockResolvedValue(successResponse),
        });
      });

      it('updates the last checked timestamp', async () => {
        await findRetryButton().vm.$emit('click');
        await waitForPromises();

        expect(findTimeAgoTooltip().props('time')).toBe(
          successResponse.data.refreshFindingTokenStatus.findingTokenStatus.updatedAt,
        );
      });

      it('updates the TokenValidityBadge status', async () => {
        expect(findTokenValidityBadge().props('status')).toBe(
          defaultProps.findingTokenStatus.status,
        );

        await findRetryButton().vm.$emit('click');
        await waitForPromises();

        expect(findTokenValidityBadge().props('status')).toBe(
          successResponse.data.refreshFindingTokenStatus.findingTokenStatus.status,
        );
      });

      it('does not show any error alerts', async () => {
        await findRetryButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('with errors', () => {
      it.each`
        scenario                | mutationHandler
        ${'GraphQL errors'}     | ${() => jest.fn().mockResolvedValue(errorResponse)}
        ${'mutation exception'} | ${() => jest.fn().mockRejectedValue(new Error('Network error'))}
      `('shows error alert when $scenario occur', async ({ mutationHandler }) => {
        createWrapperWithApollo({ mutationHandler: mutationHandler() });

        await findRetryButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Could not refresh the validity check. Please try again.',
          captureError: true,
          error: expect.any(Error),
        });
      });
    });
  });

  describe('TokenValidityBadge', () => {
    it('renders with the correct prop', () => {
      createWrapper();

      expect(findTokenValidityBadge().props('status')).toBe(defaultProps.findingTokenStatus.status);
    });

    it('passes unknown status when findingTokenStatus is null', () => {
      createWrapper({ findingTokenStatus: null });

      expect(findTokenValidityBadge().props('status')).toBe('unknown');
    });
  });

  describe('when validityRefresh feature flag is disabled', () => {
    beforeEach(() => {
      createWrapper({}, { validityRefresh: false });
    });

    it('does not render validity refresh UI', () => {
      expect(findRetryButton().exists()).toBe(false);
      expect(findLastCheckedTimestamp().exists()).toBe(false);
    });

    it('renders the token validity badge', () => {
      expect(findTokenValidityBadge().exists()).toBe(true);
    });
  });
});
