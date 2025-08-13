// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlCard, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AxiosMockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
import { createAlert } from '~/alert';
import mutations from 'ee/admin/subscriptions/show/store/mutations';
import { removeLicense } from 'ee/admin/subscriptions/show/store/actions';
import createState from 'ee/admin/subscriptions/show/store/state';
import SubscriptionActivationModal from 'ee/admin/subscriptions/show/components/subscription_activation_modal.vue';
import SubscriptionBreakdown, {
  licensedToFields,
  subscriptionDetailsFields,
} from 'ee/admin/subscriptions/show/components/subscription_breakdown.vue';
import SubscriptionDetailsCard from 'ee/admin/subscriptions/show/components/subscription_details_card.vue';
import SubscriptionDetailsHistory from 'ee/admin/subscriptions/show/components/subscription_details_history.vue';
import SubscriptionDetailsUserInfo from 'ee/admin/subscriptions/show/components/subscription_details_user_info.vue';
import SubscriptionSyncNotifications from 'ee/admin/subscriptions/show/components/subscription_sync_notifications.vue';
import {
  licensedToHeaderText,
  subscriptionDetailsHeaderText,
  subscriptionTypes,
} from 'ee/admin/subscriptions/show/constants';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { license, subscriptionPastHistory, subscriptionFutureHistory } from '../mock_data';

jest.mock('~/alert');

describe('Subscription Breakdown', () => {
  let axiosMock;
  let wrapper;
  let glModalDirective;
  let userCalloutDismissSpy;

  const [, licenseFile] = subscriptionPastHistory;
  const congratulationSvgPath = '/path/to/svg';
  const connectivityHelpURL = 'connectivity/help/url';
  const licenseRemovePath = '/license/remove/';
  const subscriptionSyncPath = '/sync/path/';

  const findDetailsCards = () => wrapper.findAllComponents(SubscriptionDetailsCard);
  const findDetailsCardFooter = () => wrapper.find('.gl-card-footer');
  const findDetailsHistory = () => wrapper.findComponent(SubscriptionDetailsHistory);
  const findDetailsUserInfo = () => wrapper.findComponent(SubscriptionDetailsUserInfo);
  const findRemoveLicenseButton = () => wrapper.findByTestId('remove-license-button');
  const findRemoveLicenseModal = () => wrapper.findComponent(GlModal);
  const findActivateSubscriptionAction = () =>
    wrapper.findByTestId('subscription-activate-subscription-action');
  const findSubscriptionActivationModal = () => wrapper.findComponent(SubscriptionActivationModal);
  const findSubscriptionSyncNotifications = () =>
    wrapper.findComponent(SubscriptionSyncNotifications);

  const createStore = ({
    didSyncFail = false,
    syncSubscriptionMock = jest.fn(),
    initialState = createState({ licenseRemovalPath: '', subscriptionSyncPath: '' }),
  } = {}) => {
    Vue.use(Vuex);

    return new Vuex.Store({
      actions: {
        syncSubscription: syncSubscriptionMock,
        removeLicense,
      },
      mutations,
      getters: {
        didSyncFail: () => didSyncFail,
        didSyncSucceed: () => false,
      },
      state: {
        ...initialState,
      },
    });
  };

  const createComponent = ({
    props = {},
    provide = {},
    stubs = {},
    mountMethod = shallowMount,
    shouldShowCallout = true,
    store = createStore(),
  } = {}) => {
    glModalDirective = jest.fn();
    userCalloutDismissSpy = jest.fn();

    wrapper = extendedWrapper(
      mountMethod(SubscriptionBreakdown, {
        store,
        directives: {
          GlModalDirective: {
            bind(_, { value }) {
              glModalDirective(value);
            },
          },
        },
        provide: {
          congratulationSvgPath,
          connectivityHelpURL,
          licenseRemovePath,
          subscriptionSyncPath,
          ...provide,
        },
        propsData: {
          subscription: license.ULTIMATE,
          subscriptionList: [...subscriptionFutureHistory, ...subscriptionPastHistory],
          ...props,
        },
        stubs: {
          UserCalloutDismisser: makeMockUserCalloutDismisser({
            dismiss: userCalloutDismissSpy,
            shouldShowCallout,
          }),
          ...stubs,
        },
      }),
    );
  };

  beforeEach(() => {
    axiosMock = new AxiosMockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('with cloud-enabled subscription data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows 2 details card', () => {
      expect(findDetailsCards()).toHaveLength(2);
    });

    it('provides the correct props to the cards', () => {
      const props = findDetailsCards().wrappers.map((w) => w.props());

      expect(props).toEqual(
        expect.arrayContaining([
          {
            detailsFields: subscriptionDetailsFields,
            headerText: subscriptionDetailsHeaderText,
            subscription: license.ULTIMATE,
          },
          {
            detailsFields: licensedToFields,
            headerText: licensedToHeaderText,
            subscription: license.ULTIMATE,
          },
        ]),
      );
    });

    it('shows the user info', () => {
      expect(findDetailsUserInfo().exists()).toBe(true);
    });

    it('provides the correct props to the user info component', () => {
      expect(findDetailsUserInfo().props('subscription')).toBe(license.ULTIMATE);
    });

    it('does not show notifications', () => {
      expect(findSubscriptionSyncNotifications().exists()).toBe(false);
    });

    it('shows the subscription details footer', () => {
      createComponent({ stubs: { GlCard, SubscriptionDetailsCard } });

      expect(findDetailsCardFooter().exists()).toBe(true);
    });

    it('updates visible of subscription activation modal when change emitted', async () => {
      findSubscriptionActivationModal().vm.$emit('change', true);

      await nextTick();

      expect(findSubscriptionActivationModal().props('visible')).toBe(true);
    });

    describe('footer buttons', () => {
      it.each`
        url                  | type                                | shouldShow
        ${licenseRemovePath} | ${subscriptionTypes.LEGACY_LICENSE} | ${true}
        ${licenseRemovePath} | ${subscriptionTypes.ONLINE_CLOUD}   | ${true}
        ${licenseRemovePath} | ${subscriptionTypes.OFFLINE_CLOUD}  | ${true}
        ${''}                | ${subscriptionTypes.LEGACY_LICENSE} | ${false}
        ${''}                | ${subscriptionTypes.ONLINE_CLOUD}   | ${false}
        ${''}                | ${subscriptionTypes.OFFLINE_CLOUD}  | ${false}
        ${undefined}         | ${subscriptionTypes.LEGACY_LICENSE} | ${false}
        ${undefined}         | ${subscriptionTypes.ONLINE_CLOUD}   | ${false}
        ${undefined}         | ${subscriptionTypes.OFFLINE_CLOUD}  | ${false}
      `(
        'with url is $url and type is $type the remove button is shown: $shouldShow',
        ({ url, type, shouldShow }) => {
          const provide = {
            connectivityHelpURL: '',
            subscriptionSyncPath: '',
            licenseRemovePath: url,
          };
          const props = { subscription: { ...license.ULTIMATE, type } };
          const stubs = { GlCard, SubscriptionDetailsCard };
          createComponent({ props, provide, stubs });

          expect(findRemoveLicenseButton().exists()).toBe(shouldShow);
        },
      );

      it('shows the activate cloud license button', () => {
        const stubs = { GlCard, SubscriptionDetailsCard };
        createComponent({ stubs });

        expect(findActivateSubscriptionAction().exists()).toBe(true);
      });
    });

    describe('with a license file', () => {
      beforeEach(() => {
        createComponent({
          props: { subscription: licenseFile },
          stubs: {
            GlCard,
            SubscriptionDetailsCard,
          },
        });
      });

      it('shows the subscription details footer', () => {
        expect(findDetailsCardFooter().exists()).toBe(true);
      });

      it('does not show the sync subscription notifications', () => {
        expect(findSubscriptionSyncNotifications().exists()).toBe(false);
      });

      it('shows modal when activate subscription action clicked', () => {
        findActivateSubscriptionAction().vm.$emit('click');

        expect(findSubscriptionActivationModal().isVisible()).toBe(true);
      });
    });

    describe('showAlert', () => {
      let consoleErrorSpy;

      beforeEach(() => {
        consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
      });

      afterEach(() => {
        createAlert.mockClear();
        consoleErrorSpy.mockRestore();
      });

      describe('when licenseError is populated', () => {
        beforeEach(async () => {
          const state = createState({
            licenseRemovalPath: licenseRemovePath,
            subscriptionSyncPath: '',
          });
          const store = createStore({ initialState: state });

          createComponent({ stubs: { GlCard, SubscriptionDetailsCard }, store });

          axiosMock.onDelete(licenseRemovePath).reply(418);

          findRemoveLicenseModal().vm.$emit('primary');

          await waitForPromises();
        });

        it('logs the error to the console and calls createAlert', () => {
          expect(consoleErrorSpy).toHaveBeenCalledTimes(1);
          expect(consoleErrorSpy).toHaveBeenCalledWith(
            '[gitlab]',
            'Error: Request failed with status code 418\n',
          );

          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while removing the license. Please try again.',
          });
        });
      });

      describe('when licenseError is not populated', () => {
        it('does not log an error to the console or call createAlert', () => {
          expect(consoleErrorSpy).not.toHaveBeenCalled();
          expect(createAlert).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('with subscription history data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the subscription history', () => {
      expect(findDetailsHistory().exists()).toBe(true);
    });

    it('provides the correct props to the subscription history component', () => {
      expect(findDetailsHistory().props('currentSubscriptionId')).toBe(license.ULTIMATE.id);
      expect(findDetailsHistory().props('subscriptionList')).toMatchObject([
        ...subscriptionFutureHistory,
        ...subscriptionPastHistory,
      ]);
    });
  });

  describe('with no subscription data', () => {
    beforeEach(() => {
      createComponent({ props: { subscription: {} } });
    });

    it('does not show user info', () => {
      expect(findDetailsUserInfo().exists()).toBe(false);
    });

    it('does not show details', () => {
      createComponent({ props: { subscription: {}, subscriptionList: [] } });

      expect(findDetailsUserInfo().exists()).toBe(false);
    });

    it('does not show the subscription details footer', () => {
      expect(findDetailsCardFooter().exists()).toBe(false);
    });
  });

  describe('with no subscription history data', () => {
    it('shows the current subscription as the only history item', () => {
      createComponent({ props: { subscriptionList: [] } });

      expect(findDetailsHistory().props('')).toMatchObject({
        currentSubscriptionId: license.ULTIMATE.id,
        subscriptionList: [license.ULTIMATE],
      });
    });
  });
});
