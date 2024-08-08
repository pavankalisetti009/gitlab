import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf } from '~/locale';
import addOnPurchaseQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchase.query.graphql';
import addOnPurchasesQuery from 'ee/usage_quotas/add_on/graphql/get_add_on_purchases.query.graphql';
import CodeSuggestionsIntro from 'ee/usage_quotas/code_suggestions/components/code_suggestions_intro.vue';
import CodeSuggestionsInfo from 'ee/usage_quotas/code_suggestions/components/code_suggestions_info_card.vue';
import CodeSuggestionsStatisticsCard from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_statistics_card.vue';
import SaasAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/saas_add_on_eligible_user_list.vue';
import SelfManagedAddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/self_managed_add_on_eligible_user_list.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE,
  DUO_ENTERPRISE_TITLE,
  DUO_PRO,
} from 'ee/usage_quotas/code_suggestions/constants';
import {
  ADD_ON_ERROR_DICTIONARY,
  ADD_ON_PURCHASE_FETCH_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import {
  noAssignedDuoProAddonData,
  deprecatedNoAssignedDuoProAddonData,
  noAssignedDuoEnterpriseAddonData,
  deprecatedNoAssignedDuoEnterpriseAddonData,
  noAssignedDuoAddonsData,
  noPurchasedAddonData,
  deprecatedNoPurchasedAddonData,
  purchasedAddonFuzzyData,
  deprecatedPurchasedAddonFuzzyData,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('ee/usage_quotas/code_suggestions/components/health_check_list.vue', () => ({
  name: 'HealthCheckList',
  template: '<div></div>',
  methods: {
    runHealthCheck: jest.fn(),
  },
}));

describe('GitLab Duo Usage', () => {
  let wrapper;

  const error = new Error('Something went wrong');

  const noAssignedAddonDataHandler = jest.fn().mockResolvedValue(noAssignedDuoProAddonData);
  const deprecatedNoAssignedAddonDataHandler = jest
    .fn()
    .mockResolvedValue(deprecatedNoAssignedDuoProAddonData);
  const noAssignedAddonErrorHandler = jest.fn().mockRejectedValue(error);

  const noAssignedEnterpriseAddonDataHandler = jest
    .fn()
    .mockResolvedValue(noAssignedDuoEnterpriseAddonData);
  const deprecatedNoAssignedEnterpriseAddonDataHandler = jest
    .fn()
    .mockResolvedValue(deprecatedNoAssignedDuoEnterpriseAddonData);

  const noAssignedDuoAddonsDataHandler = jest.fn().mockResolvedValue(noAssignedDuoAddonsData);
  const deprecatedNoAssignedDuoAddonsDataHandler = jest
    .fn()
    .mockResolvedValue(deprecatedNoAssignedDuoProAddonData);

  const noPurchasedAddonDataHandler = jest.fn().mockResolvedValue(noPurchasedAddonData);
  const deprecatedNoPurchasedAddonDataHandler = jest
    .fn()
    .mockResolvedValue(deprecatedNoPurchasedAddonData);

  const purchasedAddonFuzzyDataHandler = jest.fn().mockResolvedValue(purchasedAddonFuzzyData);
  const deprecatedPurchasedAddonFuzzyDataHandler = jest
    .fn()
    .mockResolvedValue(deprecatedPurchasedAddonFuzzyData);

  const purchasedAddonErrorHandler = jest.fn().mockRejectedValue(error);
  const deprecatedPurchasedAddonErrorHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = ({
    addOnPurchaseHandler = deprecatedNoPurchasedAddonDataHandler,
    addOnPurchasesHandler = noPurchasedAddonDataHandler,
  }) => {
    return createMockApollo([
      [addOnPurchaseQuery, addOnPurchaseHandler],
      [addOnPurchasesQuery, addOnPurchasesHandler],
    ]);
  };

  const findCodeSuggestionsIntro = () => wrapper.findComponent(CodeSuggestionsIntro);
  const findCodeSuggestionsInfo = () => wrapper.findComponent(CodeSuggestionsInfo);
  const findCodeSuggestionsStatistics = () => wrapper.findComponent(CodeSuggestionsStatisticsCard);
  const findCodeSuggestionsSubtitle = () => wrapper.findByTestId('code-suggestions-subtitle');
  const findCodeSuggestionsTitle = () => wrapper.findByTestId('code-suggestions-title');
  const findSaasAddOnEligibleUserList = () => wrapper.findComponent(SaasAddOnEligibleUserList);
  const findHealthCheckButton = () => wrapper.findByTestId('health-check-button');
  const findHealthCheckProbes = () => wrapper.findByTestId('health-check-probes');
  const findSelfManagedAddOnEligibleUserList = () =>
    wrapper.findComponent(SelfManagedAddOnEligibleUserList);
  const findErrorAlert = () => wrapper.findByTestId('add-on-purchase-fetch-error');

  const createComponent = ({ addOnPurchaseHandler, addOnPurchasesHandler, provideProps } = {}) => {
    wrapper = shallowMountExtended(CodeSuggestionsUsage, {
      provide: {
        isSaaS: true,
        ...provideProps,
      },
      apolloProvider: createMockApolloProvider({ addOnPurchaseHandler, addOnPurchasesHandler }),
      stubs: {
        HealthCheckList,
      },
    });

    return waitForPromises();
  };

  describe('Cloud Connector health status check', () => {
    const buildComponent = async (flagState = true) => {
      createComponent({
        addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: {
          isStandalonePage: true,
          isSaaS: true,
          glFeatures: {
            cloudConnectorStatus: flagState,
          },
        },
      });
      await waitForPromises();
    };

    it('does not render the health check button and the probes if feature flag is disabled', async () => {
      await buildComponent(false);
      expect(findHealthCheckButton().exists()).toBe(false);
      expect(findHealthCheckProbes().exists()).toBe(false);
    });

    it.each`
      description   | isSaaS   | isStandalonePage | expected
      ${'does'}     | ${true}  | ${true}          | ${true}
      ${'does not'} | ${true}  | ${false}         | ${false}
      ${'does not'} | ${false} | ${true}          | ${true}
      ${'does not'} | ${false} | ${false}         | ${true}
    `(
      '$description render the health check button and the probes with isSaaS is $isSaaS, and isStandalonePage is $isStandalonePage',
      async ({ isSaaS, isStandalonePage, expected } = {}) => {
        createComponent({
          addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
          addOnPurchasesHandler: noAssignedAddonDataHandler,
          provideProps: {
            isStandalonePage,
            isSaaS,
            glFeatures: {
              cloudConnectorStatus: true,
            },
          },
        });
        await waitForPromises();
        expect(findHealthCheckButton().exists()).toBe(expected);
        expect(findHealthCheckProbes().exists()).toBe(expected);
      },
    );

    it('renders the health check probes once the button is clicked', async () => {
      await buildComponent();
      findHealthCheckButton().vm.$emit('click');
      await nextTick();
      expect(findHealthCheckProbes().exists()).toBe(true);
    });

    it('re-runs the health check on repetitive button clicks', async () => {
      await buildComponent();

      const runHealthCheckSpy = jest.spyOn(findHealthCheckProbes().vm, 'runHealthCheck');
      findHealthCheckButton().vm.$emit('click');
      await nextTick();
      expect(runHealthCheckSpy).toHaveBeenCalledTimes(1);

      findHealthCheckButton().vm.$emit('click');
      await nextTick();
      expect(runHealthCheckSpy).toHaveBeenCalledTimes(2);
    });

    it('disables the button and sets it into loading state once clicked', async () => {
      await buildComponent();
      findHealthCheckButton().vm.$emit('click');
      await nextTick();
      expect(findHealthCheckButton().props('loading')).toBe(true);
      expect(findHealthCheckButton().props('disabled')).toBe(true);
    });

    it('listerns to and unblocks the button onthe health-check-completed event emitted by the HealthCheckList component', async () => {
      await buildComponent();
      findHealthCheckButton().vm.$emit('click');
      await nextTick();
      findHealthCheckProbes().vm.$emit('health-check-completed');
      await nextTick();
      expect(findHealthCheckButton().props('loading')).toBe(false);
      expect(findHealthCheckButton().props('disabled')).toBe(false);
    });
  });

  describe('when no group id prop is provided', () => {
    beforeEach(() => {
      createComponent({
        addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
        addOnPurchasesHandler: noAssignedAddonDataHandler,
      });
    });

    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        namespaceId: null,
      });
    });

    it('does not call addOnPurchase query', () => {
      expect(deprecatedNoAssignedAddonDataHandler).not.toHaveBeenCalled();
    });
  });

  describe('when group id prop is provided', () => {
    beforeEach(() => {
      createComponent({
        addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { groupId: '289561' },
      });
    });

    it('calls addOnPurchases query with appropriate props', () => {
      expect(noAssignedAddonDataHandler).toHaveBeenCalledWith({
        namespaceId: 'gid://gitlab/Group/289561',
      });
    });

    it('does not call addOnPurchase query', () => {
      expect(deprecatedNoAssignedAddonDataHandler).not.toHaveBeenCalled();
    });
  });

  describe('with no code suggestions data', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent();
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({ provideProps: { isSaaS: false } });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('renders code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(true);
      });
    });
  });

  describe('with code suggestions data', () => {
    describe('when instance is SaaS', () => {
      describe('when on the `Usage Quotas` page', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
            addOnPurchasesHandler: noAssignedAddonDataHandler,
            provideProps: { groupId: '289561' },
          });
        });

        it('does not render code suggestions title', () => {
          expect(findCodeSuggestionsTitle().exists()).toBe(false);
        });

        it('does not render code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
        });

        it('does not render code suggestions intro', () => {
          expect(findCodeSuggestionsIntro().exists()).toBe(false);
        });
      });

      describe('when on the standalone page', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
            addOnPurchasesHandler: noAssignedAddonDataHandler,
            provideProps: { isStandalonePage: true, groupId: '289561' },
          });
        });

        it('renders code suggestions title', () => {
          expect(findCodeSuggestionsTitle().text()).toBe(CODE_SUGGESTIONS_TITLE);
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            sprintf('Manage seat assignments for %{addOnName} across your instance.', {
              addOnName: CODE_SUGGESTIONS_TITLE,
            }),
          );
        });
      });

      describe('with Duo Pro add-on enabled', () => {
        describe('when getAddOnPurchases endpoint is available', () => {
          beforeEach(() => {
            return createComponent({
              addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
              addOnPurchasesHandler: noAssignedAddonDataHandler,
              provideProps: { groupId: '289561' },
            });
          });

          it('renders code suggestions statistics card for duo pro', () => {
            expect(findCodeSuggestionsStatistics().props()).toEqual({
              usageValue: 0,
              totalValue: 20,
              duoTier: DUO_PRO,
            });
          });

          it('renders code suggestions info card for duo pro', () => {
            expect(findCodeSuggestionsInfo().exists()).toBe(true);
            expect(findCodeSuggestionsInfo().props()).toEqual({
              groupId: '289561',
              duoTier: DUO_PRO,
            });
          });
        });

        describe('when getAddOnPurchases endpoint is not available', () => {
          beforeEach(() => {
            return createComponent({
              addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
              addOnPurchasesHandler: noAssignedAddonErrorHandler,
              provideProps: { groupId: '289561' },
            });
          });

          it('falls back on deprecated getAddOnPurchase endpoint', () => {
            expect(deprecatedNoAssignedAddonDataHandler).toHaveBeenCalled();

            expect(findCodeSuggestionsInfo().exists()).toBe(true);
            expect(findCodeSuggestionsInfo().props()).toEqual({
              groupId: '289561',
              duoTier: DUO_PRO,
            });
          });
        });
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchaseHandler: deprecatedNoAssignedEnterpriseAddonDataHandler,
            addOnPurchasesHandler: noAssignedEnterpriseAddonDataHandler,
            provideProps: { groupId: '289561' },
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: DUO_ENTERPRISE,
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: '289561',
            duoTier: DUO_ENTERPRISE,
          });
        });
      });

      describe('with both Duo Pro and Enterprise add-ons enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchaseHandler: deprecatedNoAssignedDuoAddonsDataHandler,
            addOnPurchasesHandler: noAssignedDuoAddonsDataHandler,
            provideProps: { groupId: '289561' },
          });
        });

        it('renders addon user list for duo enterprise', () => {
          expect(findSaasAddOnEligibleUserList().props()).toEqual({
            addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/4',
            duoTier: DUO_ENTERPRISE,
          });
        });

        it('renders code suggestions statistics card for duo enterprise', () => {
          expect(findCodeSuggestionsStatistics().props()).toEqual({
            usageValue: 0,
            totalValue: 20,
            duoTier: DUO_ENTERPRISE,
          });
        });

        it('renders code suggestions info card for duo enterprise', () => {
          expect(findCodeSuggestionsInfo().exists()).toBe(true);
          expect(findCodeSuggestionsInfo().props()).toEqual({
            groupId: '289561',
            duoTier: DUO_ENTERPRISE,
          });
        });
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
          addOnPurchasesHandler: noAssignedAddonDataHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().text()).toBe(CODE_SUGGESTIONS_TITLE);
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          sprintf('Manage seat assignments for %{addOnName} across your instance.', {
            addOnName: CODE_SUGGESTIONS_TITLE,
          }),
        );
      });

      describe('with Duo Enterprise add-on enabled', () => {
        beforeEach(() => {
          return createComponent({
            addOnPurchaseHandler: deprecatedNoAssignedEnterpriseAddonDataHandler,
            addOnPurchasesHandler: noAssignedEnterpriseAddonDataHandler,
            provideProps: { isSaaS: false },
          });
        });

        it('renders code suggestions title', () => {
          expect(findCodeSuggestionsTitle().text()).toBe(DUO_ENTERPRISE_TITLE);
        });

        it('renders code suggestions subtitle', () => {
          expect(findCodeSuggestionsSubtitle().text()).toBe(
            sprintf('Manage seat assignments for %{addOnName} across your instance.', {
              addOnName: DUO_ENTERPRISE_TITLE,
            }),
          );
        });
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('renders code suggestions statistics card', () => {
        expect(findCodeSuggestionsStatistics().props()).toEqual({
          usageValue: 0,
          totalValue: 20,
          duoTier: DUO_PRO,
        });
      });

      it('renders code suggestions info card', () => {
        expect(findCodeSuggestionsInfo().exists()).toBe(true);
      });
    });
  });

  describe('add on eligible user list', () => {
    it('renders addon user list for SaaS instance for SaaS', async () => {
      createComponent({
        addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { isSaaS: true },
      });
      await waitForPromises();

      expect(findSaasAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        duoTier: DUO_PRO,
      });
    });

    it('renders addon user list for SM instance for SM', async () => {
      createComponent({
        addOnPurchaseHandler: deprecatedNoAssignedAddonDataHandler,
        addOnPurchasesHandler: noAssignedAddonDataHandler,
        provideProps: { isSaaS: false },
      });
      await waitForPromises();

      expect(findSelfManagedAddOnEligibleUserList().props()).toEqual({
        addOnPurchaseId: 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3',
        duoTier: DUO_PRO,
      });
    });
  });

  describe('with fuzzy code suggestions data', () => {
    beforeEach(() => {
      return createComponent({
        addOnPurchaseHandler: deprecatedPurchasedAddonFuzzyDataHandler,
        addOnPurchasesHandler: purchasedAddonFuzzyDataHandler,
      });
    });

    it('renders code suggestions intro', () => {
      expect(findCodeSuggestionsIntro().exists()).toBe(true);
    });
  });

  describe('with errors', () => {
    describe('when instance is SaaS', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchaseHandler: deprecatedPurchasedAddonErrorHandler,
          addOnPurchasesHandler: purchasedAddonErrorHandler,
        });
      });

      it('does not render code suggestions title', () => {
        expect(findCodeSuggestionsTitle().exists()).toBe(false);
      });

      it('does not render code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().exists()).toBe(false);
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });

    describe('when instance is SM', () => {
      beforeEach(() => {
        return createComponent({
          addOnPurchaseHandler: deprecatedPurchasedAddonErrorHandler,
          addOnPurchasesHandler: purchasedAddonErrorHandler,
          provideProps: { isSaaS: false },
        });
      });

      it('renders code suggestions title', () => {
        expect(findCodeSuggestionsTitle().text()).toBe(CODE_SUGGESTIONS_TITLE);
      });

      it('renders code suggestions subtitle', () => {
        expect(findCodeSuggestionsSubtitle().text()).toBe(
          sprintf('Manage seat assignments for %{addOnName} across your instance.', {
            addOnName: CODE_SUGGESTIONS_TITLE,
          }),
        );
      });

      it('does not render code suggestions intro', () => {
        expect(findCodeSuggestionsIntro().exists()).toBe(false);
      });

      it('captures the original error', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
        expect(Sentry.captureException).toHaveBeenCalledWith(error, {
          tags: { vue_component: 'CodeSuggestionsUsage' },
        });
      });

      it('shows an error alert with cause', () => {
        expect(findErrorAlert().props('errorDictionary')).toMatchObject(ADD_ON_ERROR_DICTIONARY);
        const caughtError = findErrorAlert().props('error');
        expect(caughtError.cause).toBe(ADD_ON_PURCHASE_FETCH_ERROR_CODE);
      });
    });
  });
});
