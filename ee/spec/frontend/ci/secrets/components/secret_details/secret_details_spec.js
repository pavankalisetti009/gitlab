import { GlAvatar, GlLabel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetails from 'ee/ci/secrets/components/secret_details/secret_details.vue';
import { mockSecret } from '../../mock_data';

describe('SecretDetails component', () => {
  let wrapper;

  const defaultProps = {
    fullPath: 'root/banana',
  };

  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findBranches = () => wrapper.findByTestId('secret-details-branches');
  const findDescription = () => wrapper.findByTestId('secret-details-description');
  const findEnvironments = () => wrapper.findComponent(GlLabel);
  const findExpiration = () => wrapper.findByTestId('secret-details-expiration-date');
  const findLastUsed = () => wrapper.findByTestId('secret-details-last-used');
  const findMatchingBranches = () => wrapper.findByTestId('secret-details-matching-branches');
  const findMatchingEnvs = () => wrapper.findByTestId('secret-details-matching-envs');
  const findRotationReminder = () => wrapper.findByTestId('secret-details-rotation-reminder');

  const createComponent = ({ customSecret } = {}) => {
    wrapper = shallowMountExtended(SecretDetails, {
      propsData: {
        ...defaultProps,
        secret: {
          ...mockSecret(),
          ...customSecret,
        },
      },
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders and formats secret information', () => {
      expect(findEnvironments().props('title')).toBe('env::staging');
      expect(findMatchingEnvs().text()).toBe('2 matching environments');
      expect(findMatchingEnvs().attributes('href')).toBe(
        '/root/banana/-/environments?scope=active&search=staging',
      );

      expect(findBranches().text()).toBe('main');
      expect(findMatchingBranches().text()).toBe('2 matching branches');
      expect(findMatchingBranches().attributes('href')).toBe(
        '/root/banana/-/branches?state=all&search=main',
      );

      expect(findExpiration().text()).toBe('Jan 22, 2029');
      expect(findRotationReminder().text()).toBe('Sep 26, 2024 (Every 2 weeks)');

      expect(findLastUsed().text()).toBe('Just now by');
      expect(findAvatar().props('entityName')).toBe('Jane Doe');
      expect(findAvatar().props('src')).toBe(
        'https://www.gravatar.com/avatar/83f082bcac69be6bda7945a24ae1a1fda41e864296bd32356819a09cc342e384?s=80&d=identicon',
      );
    });
  });

  describe('with required fields only', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          branchMatchesCount: undefined,
          branchMatchesPath: undefined,
          description: undefined,
          envMatchesCount: undefined,
          envMatchesPath: undefined,
          lastAccessed: undefined,
          lastAccessedUser: undefined,
          rotationPeriod: undefined,
        },
      });
    });

    it("renders 'None' for optional fields that don't have values", () => {
      expect(findMatchingBranches().exists()).toBe(false);
      expect(findDescription().text()).toBe('None');
      expect(findRotationReminder().text()).toBe('None');
      expect(findLastUsed().text()).toBe('Never');
      expect(findAvatar().exists()).toBe(false);
    });
  });

  describe('pluralized fields', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          branchMatchesCount: 1,
          envMatchesCount: 1,
        },
      });
    });

    it('renders correct text for singular count', () => {
      expect(findMatchingEnvs().text()).toBe('1 matching environment');
      expect(findMatchingBranches().text()).toBe('1 matching branch');
    });
  });
});
