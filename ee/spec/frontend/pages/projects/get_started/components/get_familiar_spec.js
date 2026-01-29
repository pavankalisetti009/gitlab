import { GlCard, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GetFamiliar from 'ee/pages/projects/get_started/components/get_familiar.vue';

describe('Get Familiar component', () => {
  let wrapper;

  const createComponent = ({ glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(GetFamiliar, {
      provide: {
        glFeatures,
      },
    });
  };

  describe('with ultimate_trial_with_dap feature flag enabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { ultimateTrialWithDap: true } });
    });

    it('shows Get Familiar with DAP heading', () => {
      expect(wrapper.find('h2').text()).toBe('Get familiar with GitLab Duo Agent Platform');
    });

    it('shows the correct description text', () => {
      expect(wrapper.find('p.gl-text-subtle').text()).toBe(
        'Explore these resources to learn essential features and best practices.',
      );
    });

    it('renders the GitLab Duo Agent Platform card', () => {
      const card = wrapper.findComponent(GlCard);
      expect(card.exists()).toBe(true);
      expect(card.attributes('data-testid')).toBe('duo-code-suggestions-card');
    });

    it('does not render card header', () => {
      const card = wrapper.findComponent(GlCard);
      expect(card.attributes('header-class')).toBeUndefined();
    });

    it('displays all four DAP feature list items', () => {
      const listItems = wrapper.findAll('ul li');
      expect(listItems).toHaveLength(4);

      expect(listItems.at(0).text()).toContain('GitLab Credits:');
      expect(listItems.at(1).text()).toContain('Agentic Chat:');
      expect(listItems.at(2).text()).toContain('Agents:');
      expect(listItems.at(3).text()).toContain('Flows:');
    });

    it('displays the features list with correct accessibility label', () => {
      const featuresList = wrapper.find('ul');
      expect(featuresList.attributes('aria-label')).toBe('GitLab Duo Agent Platform features');
    });

    it('renders GitLab Credits link', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.exists()).toBe(true);
      expect(link.text()).toBe('Learn about GitLab Credits');
      expect(link.attributes('target')).toBe('_blank');
    });

    it('does not render walkthrough button', () => {
      expect(wrapper.findByTestId('walkthrough-link').exists()).toBe(false);
    });
  });

  describe('with ultimate_trial_with_dap feature flag disabled', () => {
    beforeEach(() => {
      createComponent({ glFeatures: { ultimateTrialWithDap: false } });
    });

    it('shows Get Familiar with GitLab Duo heading', () => {
      expect(wrapper.find('h2').text()).toBe('Get familiar with GitLab Duo');
    });

    it('shows the correct description text', () => {
      expect(wrapper.find('p.gl-text-subtle').text()).toBe(
        'Explore these resources to learn essential features and best practices.',
      );
    });

    it('renders the GitLab Duo Code Suggestions card', () => {
      const card = wrapper.findComponent(GlCard);
      expect(card.exists()).toBe(true);
      expect(card.attributes('data-testid')).toBe('duo-code-suggestions-card');
    });

    it('renders card header', () => {
      const card = wrapper.findComponent(GlCard);
      expect(card.props('headerClass')).toBe('gl-font-bold');
    });

    it('displays all four code suggestions feature list items', () => {
      const listItems = wrapper.findAll('ul li');
      expect(listItems).toHaveLength(4);

      expect(listItems.at(0).text()).toContain('Code completion:');
      expect(listItems.at(1).text()).toContain('Code generation:');
      expect(listItems.at(2).text()).toContain('Context-aware suggestions:');
      expect(listItems.at(3).text()).toContain('Support for multiple languages:');
    });

    it('displays the features list with correct accessibility label', () => {
      const featuresList = wrapper.find('ul');
      expect(featuresList.attributes('aria-label')).toBe('GitLab Duo code features');
    });

    it('renders walkthrough button', () => {
      const button = wrapper.findByTestId('walkthrough-link');
      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Try walkthrough');
      expect(button.attributes('href')).toBe(
        'https://gitlab.navattic.com/gitlab-with-duo-get-started-page',
      );
      expect(button.attributes('target')).toBe('_blank');
    });

    it('does not render GitLab Credits link', () => {
      const link = wrapper.findComponent(GlLink);
      expect(link.exists()).toBe(false);
    });
  });
});
