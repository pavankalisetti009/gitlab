import { GlSprintf, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { PROMO_URL } from '~/constants';
import { visitUrl } from 'jh_else_ce/lib/utils/url_utility';
import CodeSuggestionsInfoCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { ADD_ON_PURCHASE_FETCH_ERROR_CODE } from 'ee/usage_quotas/error_constants';
import getGitlabSubscriptionQuery from 'ee/fulfillment/shared_queries/gitlab_subscription.query.graphql';
import { getMockSubscriptionData } from 'ee_jest/usage_quotas/seats/mock_data';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const defaultProvide = {
  addDuoProHref: 'http://customers.gitlab.com/namespaces/10/duo_pro_seats',
  isSaaS: true,
  subscriptionName: null,
  subscriptionStartDate: '2023-03-16',
  subscriptionEndDate: '2024-03-16',
  duoProActiveTrialStartDate: null,
  duoProActiveTrialEndDate: null,
};

describe('CodeSuggestionsInfoCard', () => {
  let wrapper;

  const defaultProps = { groupId: '4321' };
  const defaultApolloData = {
    subscription: {
      canAddSeats: false,
      canRenew: false,
      communityPlan: false,
      canAddDuoProSeats: true,
    },
    userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
  };

  let queryHandlerMock = jest.fn().mockResolvedValue({
    data: defaultApolloData,
  });

  const findCodeSuggestionsDescription = () => wrapper.findByTestId('description');
  const findCodeSuggestionsSubscriptionInfo = () => wrapper.findByTestId('subscription-info');
  const findCodeSuggestionsLearnMoreLink = () =>
    wrapper.findByTestId('usage-quotas-gitlab-duo-tab-code-suggestions-link');
  const findCodeSuggestionsInfoTitle = () => wrapper.findByTestId('title');
  const findAddSeatsButton = () => wrapper.findComponent(GlButton);
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);
  const findPurchaseSeatsButton = () =>
    wrapper.findByTestId('usage-quotas-gitlab-duo-tab-active-trial-purchase-seats-button');
  const findContactSalesButton = () => wrapper.findComponent(HandRaiseLeadButton);

  const createMockApolloProvider = ({ subscriptionData }) => {
    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, queryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getGitlabSubscriptionQuery,
      data: subscriptionData,
    });
    return mockApollo;
  };

  const createComponent = (options = {}) => {
    const { props = {}, provide = {}, subscriptionData = {} } = options;
    const apolloProvider = createMockApolloProvider(subscriptionData);

    wrapper = shallowMountExtended(CodeSuggestionsInfoCard, {
      propsData: { ...defaultProps, ...props },
      provide: { ...defaultProvide, ...provide },
      apolloProvider,
      stubs: {
        GlSprintf,
        LimitedAccessModal,
        UsageStatistics: {
          template: `
            <div>
                <slot name="actions"></slot>
                <slot name="description"></slot>
                <slot name="additional-info"></slot>
            </div>
            `,
        },
      },
    });
  };

  describe('when `isLoading` computed value is `true`', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders `GlSkeletonLoader`', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('Add Seats button is not shown while loading', () => {
      createComponent();

      expect(findAddSeatsButton().exists()).toBe(false);
    });
  });

  describe('general rendering', () => {
    beforeEach(async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    describe('with Duo Pro add-on enabled', () => {
      beforeEach(async () => {
        jest.spyOn(Tracking, 'event');

        createComponent({ props: { duoTier: 'pro' } });

        // wait for apollo to load
        await waitForPromises();
      });

      it('renders the title text', () => {
        expect(findCodeSuggestionsInfoTitle().text()).toBe('Subscription');
      });

      it('tracks the page view correctly', () => {
        expect(Tracking.event).toHaveBeenCalledWith(
          'groups:usage_quotas:index',
          'view_group_duo_pro_usage_pageload',
          expect.objectContaining({
            label: 'duo_pro_add_on_tab',
          }),
        );
      });
    });

    describe('with Duo Enterprise add-on enabled', () => {
      beforeEach(async () => {
        createComponent({ props: { duoTier: 'enterprise' } });

        // wait for apollo to load
        await waitForPromises();
      });

      it('renders the title text', () => {
        expect(findCodeSuggestionsInfoTitle().text()).toBe('Subscription');
      });
    });

    it('renders the description text', () => {
      expect(findCodeSuggestionsDescription().text()).toBe(
        "Code Suggestions uses generative AI to suggest code while you're developing.",
      );
    });

    describe('with subscription date info', () => {
      const outputStartDate = 'Mar 16, 2023';
      const outputEndDate = 'Mar 16, 2024';

      describe('with Saas', () => {
        beforeEach(async () => {
          createComponent({
            subscriptionData: getMockSubscriptionData({ code: 'premium', name: 'Premium' }),
          });

          // wait for apollo to load
          await waitForPromises();
        });
        it('renders the correct start date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputStartDate);
        });

        it('renders the correct end date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputEndDate);
        });
      });
      describe('with SM', () => {
        beforeEach(async () => {
          createComponent({ subscriptionData: {} });

          // wait for apollo to load
          await waitForPromises();
        });
        it('renders the correct start date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputStartDate);
        });

        it('renders the correct end date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputEndDate);
        });
      });
      describe('with subscription dates not available', () => {
        beforeEach(async () => {
          createComponent({
            subscriptionData: { subscription: { endDate: null, startDate: null } },
            provide: { subscriptionStartDate: null, subscriptionEndDate: null },
          });

          // wait for apollo to load
          await waitForPromises();
        });
        it('renders the correct start date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain('Not available');
        });

        it('renders the correct end date text', () => {
          expect(findCodeSuggestionsSubscriptionInfo().text()).toContain('Not available');
        });
      });
    });

    describe('with a Duo Pro add-on trial', () => {
      const outputStartDate = 'Jan 1, 2024';
      const outputEndDate = 'Feb 1, 2024';

      beforeEach(async () => {
        jest.spyOn(Tracking, 'event');

        createComponent({
          provide: {
            duoProActiveTrialStartDate: '2024-01-01',
            duoProActiveTrialEndDate: '2024-02-01',
          },
        });

        await waitForPromises();
      });

      it('renders the title text', () => {
        expect(findCodeSuggestionsInfoTitle().text()).toBe('Trial');
      });

      it('renders the trial start date', () => {
        expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputStartDate);
      });

      it('renders the trial end date', () => {
        expect(findCodeSuggestionsSubscriptionInfo().text()).toContain(outputEndDate);
      });

      it('tracks the page view correctly', () => {
        expect(Tracking.event).toHaveBeenCalledWith(
          'groups:usage_quotas:index',
          'view_group_duo_pro_usage_pageload',
          expect.objectContaining({
            label: 'duo_pro_add_on_tab_active_trial',
          }),
        );
      });

      describe('buttons', () => {
        it('sets to the correct props to the hand raise lead (contact sales) button', () => {
          expect(findContactSalesButton().props()).toMatchObject({
            glmContent: 'usage-quotas-gitlab-duo-tab',
            ctaTracking: {
              category: 'groups:usage_quotas:index',
              action: 'click_button',
              label: 'duo_pro_contact_sales',
            },
          });
        });

        it('visits the correct url and tracks the purchase seats button when clicked', () => {
          findPurchaseSeatsButton().vm.$emit('click');

          expect(Tracking.event).toHaveBeenCalledWith(
            'groups:usage_quotas:index',
            'click_purchase_seats_button_group_duo_pro_usage_page',
            expect.objectContaining({
              label: 'duo_pro_purchase_seats',
            }),
          );

          expect(visitUrl).toHaveBeenCalledWith(defaultProvide.addDuoProHref);
        });

        it('visits the correct url and tracks the learn more link when clicked', () => {
          findCodeSuggestionsLearnMoreLink().vm.$emit('click');

          expect(Tracking.event).toHaveBeenCalledWith(
            'groups:usage_quotas:index',
            'click_marketing_link_group_duo_pro_usage_page',
            expect.objectContaining({
              label: 'duo_pro_marketing_page',
            }),
          );

          expect(visitUrl).toHaveBeenCalledWith(`${PROMO_URL}/gitlab-duo/`);
        });
      });
    });
  });

  describe('add seats button', () => {
    it('is rendered after apollo is loaded', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();
      expect(findAddSeatsButton().exists()).toBe(true);
    });

    describe('when subscriptionPermissions returns error', () => {
      const mockError = new Error('Woops, error in permissions call');
      beforeEach(async () => {
        queryHandlerMock = jest.fn().mockRejectedValueOnce(mockError);
        createComponent();

        await waitForPromises();
      });

      it('captures the ooriginal error in subscriptionPermissions call', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(mockError, {
          tags: { vue_component: 'CodeSuggestionsUsageInfoCard' },
        });
      });

      it('emits the error', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
        const caughtError = wrapper.emitted('error')[0][0];
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });

      it('shows the button', () => {
        // When clicked the button will redirect a customer and we will handle the error on CustomersPortal side
        expect(findAddSeatsButton().exists()).toBe(true);
      });
    });

    describe('tracking', () => {
      beforeEach(() => {
        jest.spyOn(Tracking, 'event');
      });

      it.each`
        isSaaS   | label
        ${true}  | ${'add_duo_pro_saas'}
        ${false} | ${'add_duo_pro_sm'}
      `('tracks the click with correct labels', async ({ isSaaS, label }) => {
        createComponent({ provide: { isSaaS } });
        await waitForPromises();
        findAddSeatsButton().vm.$emit('click');
        expect(Tracking.event).toHaveBeenCalledWith(
          undefined,
          'click_add_seats_button_group_duo_pro_usage_page',
          expect.objectContaining({
            property: 'usage_quotas_page',
            label,
          }),
        );
      });
    });

    describe('limited access modal', () => {
      describe.each`
        canAddDuoProSeats | limitedAccessReason
        ${false}          | ${'MANAGED_BY_RESELLER'}
        ${false}          | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddDuoProSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            queryHandlerMock = jest.fn().mockResolvedValue({
              data: {
                subscription: {
                  canAddSeats: false,
                  canRenew: false,
                  communityPlan: false,
                  canAddDuoProSeats,
                },
                userActionAccess: { limitedAccessReason },
              },
            });
            createComponent();
            await waitForPromises();

            findAddSeatsButton().vm.$emit('click');

            await nextTick();
          });

          it('shows modal', () => {
            expect(findLimitedAccessModal().isVisible()).toBe(true);
          });

          it('sends correct props', () => {
            expect(findLimitedAccessModal().props('limitedAccessReason')).toBe(limitedAccessReason);
          });

          it('does not navigate to URL', () => {
            expect(visitUrl).not.toHaveBeenCalled();
          });
        },
      );

      describe.each`
        canAddDuoProSeats | limitedAccessReason
        ${true}           | ${'MANAGED_BY_RESELLER'}
        ${true}           | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddDuoProSeats=$canAddDuoProSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddDuoProSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            queryHandlerMock = jest.fn().mockResolvedValue({
              data: {
                subscription: {
                  canAddSeats: false,
                  canRenew: false,
                  communityPlan: false,
                  canAddDuoProSeats,
                },
                userActionAccess: { limitedAccessReason },
              },
            });
            createComponent();
            await waitForPromises();

            findAddSeatsButton().vm.$emit('click');
            await nextTick();
          });

          it('does not show modal', () => {
            expect(findLimitedAccessModal().exists()).toBe(false);
          });

          it('navigates to URL', () => {
            expect(visitUrl).toHaveBeenCalledWith(defaultProvide.addDuoProHref);
          });
        },
      );
    });
  });
});
