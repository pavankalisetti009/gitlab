import { GlPopover, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UltimatePlanBilling from 'ee/groups/billing/components/ultimate_plan_billing.vue';

describe('UltimatePlanBilling', () => {
  let wrapper;

  const defaultProps = {
    isNewTrialType: true,
    trialActive: true,
    creditsPopover: {
      text: 'Limited time offer. %{linkStart}See details and promo terms%{linkEnd}',
      url: 'https://example.com/credits',
    },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UltimatePlanBilling, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGitLabCreditsElement = () => wrapper.findByTestId('ultimate-gitlab-credits');
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findGlLink = () => wrapper.findComponent(GlLink);

  describe('GitLab Credits section', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('when trialActive is true', () => {
      it('displays the trial active credits text', () => {
        expect(findGitLabCreditsElement().text()).toContain(
          'Includes $24 in GitLab Credits per user per month',
        );
      });
    });

    describe('when trialActive is false', () => {
      beforeEach(() => {
        createComponent({ trialActive: false });
      });

      it('displays the non-trial credits text', () => {
        expect(findGitLabCreditsElement().text()).toContain(
          '$24 in GitLab Credits per user per month',
        );
      });
    });

    describe('popover functionality', () => {
      it('popover targets the credits element', () => {
        expect(findGlPopover().props('target')).toBe('ultimate-gitlab-credits');
      });

      it('link has correct href from creditsPopover prop', () => {
        const link = findGlLink();

        expect(link.props('target')).toBe('_blank');
        expect(link.props('href')).toBe(defaultProps.creditsPopover.url);
      });
    });
  });
});
