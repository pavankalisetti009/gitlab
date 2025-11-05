import { GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { makeMockUserGroupCalloutDismisser } from 'helpers/mock_user_group_callout_dismisser';
import PremiumMessageDuringTrial from 'ee/vue_shared/premium_message_during_trial/components/premium_message_during_trial.vue';

describe('PremiumMessageDuringTrial', () => {
  let wrapper;
  let userGroupCalloutDismissSpy;

  const defaultProps = {
    featureId: 'test-feature',
    groupId: 'test-group-id',
    page: 'project',
    upgradeUrl: '/upgrade',
  };

  const createComponent = (props = {}) => {
    userGroupCalloutDismissSpy = jest.fn();

    wrapper = mountExtended(PremiumMessageDuringTrial, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        UserGroupCalloutDismisser: makeMockUserGroupCalloutDismisser({
          dismiss: userGroupCalloutDismissSpy,
          shouldShowCallout: true,
        }),
      },
    });
  };

  const findLearnMoreLink = () => wrapper.findByTestId('learn-more-link');
  const findUpgradeButton = () => wrapper.findByTestId('upgrade-button');
  const findCloseButton = () => wrapper.findByTestId('dismiss-button');
  const findCloseIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  it('displays correct content for project page', () => {
    expect(wrapper.text()).toContain('Accelerate your workflow with GitLab Duo Core');
    expect(findLearnMoreLink().props('href')).toBe('/help/user/gitlab_duo/_index');

    expect(wrapper.text()).toContain(
      'AI across the software development lifecycle. To keep this Premium feature, upgrade before your trial ends.',
    );
  });

  it('renders learn more button with correct attributes', () => {
    const learnMoreLink = findLearnMoreLink();

    expect(learnMoreLink.props('target')).toBe('_blank');
    expect(learnMoreLink.text()).toBe('Learn more');
  });

  it('renders upgrade button with correct attributes', () => {
    const upgradeButton = findUpgradeButton();

    expect(upgradeButton.props('href')).toBe(defaultProps.upgradeUrl);
    expect(upgradeButton.text()).toBe('Upgrade to Premium');
  });

  it('renders close button with correct attributes', () => {
    expect(findCloseButton().isVisible()).toBe(true);
  });

  it('renders close icon', () => {
    const closeIcon = findCloseIcon();

    expect(closeIcon.exists()).toBe(true);
    expect(closeIcon.props('name')).toBe('close');
  });

  describe('different page types', () => {
    it('displays correct content for repository page', () => {
      createComponent({ page: 'repository' });

      expect(wrapper.text()).toContain('Keep your repositories synchronized with pull mirroring');
      expect(findLearnMoreLink().props('href')).toBe('/help/user/project/repository/mirror/pull');

      expect(wrapper.text()).toContain(
        'Automatically pull from upstream repositories. To keep this Premium feature, upgrade before your trial ends.',
      );
    });

    it('displays correct content for mrs page', () => {
      createComponent({ page: 'mrs' });

      expect(wrapper.text()).toContain(
        'Control your merge request review process with approval rules',
      );

      expect(findLearnMoreLink().props('href')).toBe(
        '/help/user/project/merge_requests/approvals/rules',
      );

      expect(wrapper.text()).toContain(
        'Set approval requirements and specific reviewers. To keep this Premium feature, upgrade before your trial ends.',
      );
    });
  });

  describe('with tracking', () => {
    let trackingSpy;

    beforeEach(() => {
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

      createComponent();
    });

    afterEach(() => {
      unmockTracking();
    });

    it('tracks render event', () => {
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render_project_card', {});
    });

    it('tracks learn more click', () => {
      findLearnMoreLink().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'click_learn_more_link_on_project_card',
        {},
      );
    });

    it('tracks upgrade click', () => {
      findUpgradeButton().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'click_upgrade_button_on_project_card',
        {},
      );
    });

    it('tracks dismiss event', () => {
      findCloseButton().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'click_dismiss_button_on_project_card',
        {},
      );
    });
  });
});
