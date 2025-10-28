import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable, GlCard, GlProgressBar, GlAlert, GlKeysetPagination } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import UsageByUserTab from 'ee/usage_quotas/usage_billing/components/usage_by_user_tab.vue';
import getSubscriptionUsersUsageQuery from 'ee/usage_quotas/usage_billing/graphql/get_subscription_users_usage.query.graphql';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { PAGE_SIZE } from 'ee/usage_quotas/usage_billing/constants';
import { mockUsersUsageDataWithPool, mockUsersUsageDataWithZeroAllocation } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/logger');

describe('UsageByUserTab', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  /** @type {jest.Mock} */
  let getSubscriptionUsersUsageQueryHandler;

  const createComponent = ({ mountFn = shallowMountExtended, provide, propsData } = {}) => {
    const defaultClient = createMockClient([
      [getSubscriptionUsersUsageQuery, getSubscriptionUsersUsageQueryHandler],
    ]);

    const apolloProvider = new VueApollo({ defaultClient });

    wrapper = mountFn(UsageByUserTab, {
      apolloProvider,
      propsData: { hasCommitment: true, ...propsData },
      provide: {
        namespacePath: null,
        userUsagePath: '/path/to/user/:username',
        ...provide,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findProgressBars = () => wrapper.findAllComponents(GlProgressBar);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    getSubscriptionUsersUsageQueryHandler = jest.fn();
  });

  describe('normal state', () => {
    beforeEach(() => {
      getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockUsersUsageDataWithPool);
    });

    // NOTE: with limited GraphQL API, we can't test this functionality at the moment
    // TODO: tests to be restored within https://gitlab.com/gitlab-org/gitlab/-/issues/573644
    /* eslint-disable jest/no-disabled-tests */
    describe.skip('rendering cards', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders total users card', () => {
        const cards = findCards();

        expect(cards.at(0).text()).toMatchInterpolatedText('50 Total users (active users)');
        expect(cards.at(1).text()).toMatchInterpolatedText('35 Users using allocation');
        expect(cards.at(2).text()).toMatchInterpolatedText('10 Users blocked');
      });
    });

    describe('rendering table', () => {
      const findRows = () => findTable().find('tbody').findAll('tr');
      const findFirstRow = () => findRows().at(0);
      const findCell = (index) => findFirstRow().find(`td:nth-child(${index})`);

      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('renders the table with correct props', () => {
        expect(findTable().props('fields')).toEqual([
          {
            key: 'user',
            label: 'User',
          },
          {
            key: 'includedCredits',
            label: 'Included used',
          },
          {
            key: 'totalCreditsUsed',
            label: 'Total credits used',
          },
        ]);
      });

      describe('rendering table', () => {
        it('will render all rows', () => {
          const rows = findRows();
          expect(rows).toHaveLength(8);
        });

        describe.each`
          username      | displayName        | includedCreditsUsed | includedCreditsUsedPercent | totalCreditsUsed
          ${'ajohnson'} | ${'Alice Johnson'} | ${'450 / 500'}      | ${90}                      | ${'473'}
        `(
          'rendering $userName $username',
          ({
            username,
            displayName,
            includedCreditsUsed,
            includedCreditsUsedPercent,
            totalCreditsUsed,
          }) => {
            describe('user cell', () => {
              it('renders user avatar with link to the user details page', () => {
                const userAvatar = findCell(1).findComponent(UserAvatarLink);
                expect(userAvatar.props('linkHref')).toBe(`/path/to/user/${username}`);
              });

              it('renders user name', () => {
                const cell = findCell(1);
                expect(cell.text()).toBe(displayName);
              });
            });

            describe('included credits used cell', () => {
              it('renders the included usage values', () => {
                const cell = findCell(2);
                expect(cell.text()).toBe(includedCreditsUsed);
              });

              it('renders the progress bars for included credits', () => {
                const cell = findCell(2);
                const progressBar = cell.findComponent(GlProgressBar);

                expect(progressBar.props('value')).toBe(includedCreditsUsedPercent);
              });
            });

            it('renders total credits used cell', () => {
              const cell = findCell(3);

              expect(cell.text()).toBe(totalCreditsUsed);
            });
          },
        );
      });

      describe('with zero allocation', () => {
        beforeEach(async () => {
          getSubscriptionUsersUsageQueryHandler.mockResolvedValue(
            mockUsersUsageDataWithZeroAllocation,
          );
          createComponent({ mountFn: mountExtended });
          await waitForPromises();
        });

        it('renders the progress bar with 0 value when allocationTotal is 0', () => {
          const progressBars = findProgressBars();

          expect(progressBars).toHaveLength(5);
          // testing the first two instances
          expect(progressBars.at(0).props('value')).toBe(0);
          expect(progressBars.at(1).props('value')).toBe(0);
        });
      });
    });

    describe('pagination', () => {
      const findPagination = () => wrapper.findComponent(GlKeysetPagination);

      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });
        await waitForPromises();
      });

      it('calls the graphql query on load', () => {
        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: null,
            first: PAGE_SIZE,
            last: null,
          }),
        );
      });

      it('will render the pagination', () => {
        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toEqual(
          expect.objectContaining(
            mockUsersUsageDataWithPool.data.subscriptionUsage.usersUsage.users.pageInfo,
          ),
        );
      });

      it('navigates to next page', async () => {
        getSubscriptionUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('next', '42');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: '42',
            before: null,
            first: PAGE_SIZE,
            last: null,
          }),
        );
      });

      it('navigates to prev page', async () => {
        getSubscriptionUsersUsageQueryHandler.mockClear();

        findPagination().vm.$emit('prev', '37');
        await nextTick();

        expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            after: null,
            before: '37',
            first: null,
            last: PAGE_SIZE,
          }),
        );
      });
    });
  });

  describe('SaaS', () => {
    beforeEach(async () => {
      createComponent({ provide: { namespacePath: 'some_namespace' } });
      await waitForPromises();
    });

    it('passes the namespace path to the API', () => {
      expect(getSubscriptionUsersUsageQueryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          namespacePath: 'some_namespace',
        }),
      );
    });
  });

  describe('loading state', () => {
    beforeEach(async () => {
      getSubscriptionUsersUsageQueryHandler.mockReturnValue(new Promise(() => {}));
      createComponent();
      await waitForPromises();
    });

    it('doesnt render the table', () => {
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      getSubscriptionUsersUsageQueryHandler.mockRejectedValue(new Error('Failed to fetch data'));
      createComponent();
      await waitForPromises();
    });

    it('reports the error', () => {
      expect(logError).toHaveBeenCalled();
      expect(captureException).toHaveBeenCalled();
    });

    it('renders alert', () => {
      expect(findAlert().exists()).toBe(true);
    });
  });
});
