import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import { SUPPORT_URL } from '~/sessions/new/constants';

describe('DuoCoreUpgradeCard', () => {
  let wrapper;

  const createComponent = ({ addDuoProHref = 'https://customers.gitlab.com' } = {}) => {
    wrapper = shallowMount(DuoCoreUpgradeCard, {
      provide: {
        addDuoProHref,
      },
    });
  };

  const findButtons = () => wrapper.findAllComponents(GlButton);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays pre-title, title and description', () => {
      expect(wrapper.text()).toContain('Upgrade to');
      expect(wrapper.text()).toContain('GitLab Duo Pro or Enterprise');
      expect(wrapper.text()).toContain(
        'Unlock advanced AI-powered capabilities with the Premium or Ultimate tier designed for your development needs',
      );
    });

    it('renders a button for upgrading', () => {
      expect(findButtons()).toHaveLength(2);
      expect(findButtons().at(0).attributes('href')).toBe('https://customers.gitlab.com');
      expect(findButtons().at(0).text()).toBe('Purchase Duo Pro seats');
      expect(findButtons().at(1).attributes('href')).toBe(SUPPORT_URL);
      expect(findButtons().at(1).text()).toBe('Contact sales for Duo Enterprise');
    });
  });
});
