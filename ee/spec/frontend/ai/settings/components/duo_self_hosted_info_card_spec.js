import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoSelfHostedInfoCard from 'ee/ai/settings/components/duo_self_hosted_info_card.vue';

describe('DuoSelfHostedInfoCard', () => {
  let wrapper;

  const duoSelfHostedPath = '/admin/ai/duo_self_hosted';
  const createComponent = () => {
    wrapper = shallowMountExtended(DuoSelfHostedInfoCard, {
      provide: {
        duoSelfHostedPath,
      },
    });
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findInfoCardHeader = () => wrapper.find('h2');
  const findInfoCardSecondaryHeader = () =>
    wrapper.findByTestId('duo-self-hosted-card-secondary-header');
  const findInfoCardDescription = () => wrapper.findByTestId('duo-self-hosted-card-description');
  const findConfigurationButton = () => wrapper.findComponent(GlButton);

  it('renders info card and correct copy', () => {
    createComponent();

    expect(findCard().exists()).toBe(true);
    expect(findInfoCardHeader().text()).toContain('GitLab Duo Self-Hosted');
    expect(findInfoCardSecondaryHeader().text()).toContain('Configure AI features');
    expect(findInfoCardDescription().text()).toMatch(
      'Assign self-hosted models to specific AI-native features.',
    );
  });

  it('renders a CTA button', () => {
    createComponent();

    expect(findConfigurationButton().text()).toBe('Configure GitLab Duo Self-Hosted');
    expect(findConfigurationButton().attributes('to')).toBe(duoSelfHostedPath);
  });
});
