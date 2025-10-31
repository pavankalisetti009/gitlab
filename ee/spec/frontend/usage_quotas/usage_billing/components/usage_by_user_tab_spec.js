import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable, GlProgressBar, GlAlert, GlKeysetPagination } from '@gitlab/ui';
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
  const findProgressBars = () => wrapper.findAllComponents(GlProgressBar);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    getSubscriptionUsersUsageQueryHandler = jest.fn();
  });

  describe('normal state', () => {
    beforeEach(() => {
      getSubscriptionUsersUsageQueryHandler.mockResolvedValue(mockUsersUsageDataWithPool);
    });

    describe('rendering table', () => {
      const findRows = () => findTable().find('tbody').findAll('tr');

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
          index | username      | displayName        | includedCreditsUsed | includedCreditsUsedPercent | totalCreditsUsed
          ${0}  | ${'ajohnson'} | ${'Alice Johnson'} | ${'500 / 500'}      | ${100}                     | ${'640'}
          ${1}  | ${'bsmith'}   | ${'Bob Smith'}     | ${'500 / 500'}      | ${100}                     | ${'500'}
          ${2}  | ${'cdavis'}   | ${'Carol Davis'}   | ${'50 / 500'}       | ${10}                      | ${'50'}
        `(
          '$index: rendering $displayName ($username)',
          ({
            index,
            username,
            displayName,
            includedCreditsUsed,
            includedCreditsUsedPercent,
            totalCreditsUsed,
          }) => {
            const findRow = () => findRows().at(index);
            const findCell = (cellIndex) => findRow().find(`td:nth-child(${cellIndex})`);

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
