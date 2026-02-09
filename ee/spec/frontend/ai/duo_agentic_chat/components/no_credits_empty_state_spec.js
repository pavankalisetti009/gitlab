import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import NoCreditsEmptyState from 'ee/ai/duo_agentic_chat/components/no_credits_empty_state.vue';

describe('NoCreditsEmptyState', () => {
  let wrapper;

  const defaultProps = {
    isTrial: false,
    buyAddonPath: '/groups/test-group/-/billings',
    canBuyAddon: true,
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(NoCreditsEmptyState, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findContainer = () => wrapper.findByTestId('no-credits-empty-state');
  const findImage = () => wrapper.find('img');
  const findHeading = () => wrapper.find('h2');
  const findDescription = () => wrapper.find('p');
  const findLearnMoreButton = () => wrapper.findByTestId('learn-more-button');
  const findPrimaryCta = () => wrapper.findByTestId('primary-cta');

  describe('rendering', () => {
    it('renders the container and image', () => {
      createComponent();

      expect(findContainer().exists()).toBe(true);
      expect(findImage().exists()).toBe(true);
    });

    it('always renders learn more button', () => {
      createComponent();

      expect(findLearnMoreButton().exists()).toBe(true);
      expect(findLearnMoreButton().attributes('href')).toContain('duo_agent_platform');
    });
  });

  describe('trial vs paid distinction', () => {
    describe('when user is on paid subscription', () => {
      beforeEach(() => {
        createComponent({ isTrial: false });
      });

      it('shows paid headline', () => {
        expect(findHeading().text()).toBe('No credits remain for this billing period');
      });

      it('shows paid description mentioning purchasing credits', () => {
        expect(findDescription().text()).toContain('Purchase more credits');
      });

      it('shows "Purchase more credits" as primary CTA', () => {
        expect(findPrimaryCta().text()).toBe('Purchase more credits');
      });
    });

    describe('when user is on trial', () => {
      beforeEach(() => {
        createComponent({ isTrial: true });
      });

      it('shows trial headline', () => {
        expect(findHeading().text()).toBe('No credits remain on your trial');
      });

      it('shows trial description mentioning upgrading', () => {
        expect(findDescription().text()).toContain('Upgrade to a paid subscription');
      });

      it('shows "Upgrade to Premium" as primary CTA', () => {
        expect(findPrimaryCta().text()).toBe('Upgrade to Premium');
      });
    });
  });

  describe('CTA visibility', () => {
    it('shows primary CTA when user can buy addon and path is provided', () => {
      createComponent({ canBuyAddon: true, buyAddonPath: '/billings' });

      expect(findPrimaryCta().exists()).toBe(true);
      expect(findPrimaryCta().attributes('href')).toBe('/billings');
    });

    it('hides primary CTA when user cannot buy addon', () => {
      createComponent({ canBuyAddon: false, buyAddonPath: '/billings' });

      expect(findPrimaryCta().exists()).toBe(false);
    });

    it('hides primary CTA when buy addon path is empty', () => {
      createComponent({ canBuyAddon: true, buyAddonPath: '' });

      expect(findPrimaryCta().exists()).toBe(false);
    });
  });

  describe('tracking', () => {
    describe('view event', () => {
      it('tracks view event with "paid" label for paid users', () => {
        createComponent({ isTrial: false });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks view event with "trial" label for trial users', () => {
        createComponent({ isTrial: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'view_duo_agentic_no_credits_empty_state',
          { label: 'trial' },
          undefined,
        );
      });
    });

    describe('click events', () => {
      it('tracks learn more click with paid label', async () => {
        createComponent({ isTrial: false });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findLearnMoreButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_learn_more',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks learn more click with trial label', async () => {
        createComponent({ isTrial: true });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findLearnMoreButton().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_learn_more',
          { label: 'trial' },
          undefined,
        );
      });

      it('tracks purchase credits click for paid users with paid label', async () => {
        createComponent({ isTrial: false, canBuyAddon: true, buyAddonPath: '/billings' });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findPrimaryCta().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_purchase_credits',
          { label: 'paid' },
          undefined,
        );
      });

      it('tracks upgrade premium click for trial users with trial label', async () => {
        createComponent({ isTrial: true, canBuyAddon: true, buyAddonPath: '/billings' });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        trackEventSpy.mockClear();

        await findPrimaryCta().vm.$emit('click');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_duo_agentic_no_credits_upgrade_premium',
          { label: 'trial' },
          undefined,
        );
      });
    });
  });
});
