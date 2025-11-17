import { GlLabel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetails from 'ee/ci/secrets/components/secret_details/secret_details.vue';
import { mockSecret } from '../../mock_data';

describe('SecretDetails component', () => {
  let wrapper;

  const findBranches = () => wrapper.findByTestId('secret-details-branches');
  const findDescription = () => wrapper.findByTestId('secret-details-description');
  const findRotationReminder = () => wrapper.findByTestId('secret-details-rotation-reminder');
  const findHealthStatus = () => wrapper.findByTestId('secret-details-health-status');
  const findEnvironments = () => wrapper.findComponent(GlLabel);

  const createComponent = ({ customSecret } = {}) => {
    wrapper = shallowMountExtended(SecretDetails, {
      propsData: {
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
      expect(findDescription().text()).toBe('This is a secret');
      expect(findEnvironments().props('title')).toBe('env::staging');
      expect(findBranches().text()).toBe('main');
    });
  });

  describe('with required fields only', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          description: undefined,
        },
      });
    });

    it("renders 'None' for optional fields that don't have values", () => {
      expect(findDescription().text()).toBe('None');
      expect(findRotationReminder().text()).toBe('None');
    });
  });

  describe('with rotation info', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          rotationInfo: {
            rotationIntervalDays: 7,
            nextReminderAt: '2025-10-08T00:00:00Z',
            status: 'APPROACHING',
          },
        },
      });
    });

    it('renders rotation reminder information', () => {
      expect(findRotationReminder().text()).toBe('Oct 8, 2025 (Every 7 days)');
    });
  });

  describe('health status', () => {
    it.each`
      status                  | text                 | variant      | tooltip
      ${'COMPLETED'}          | ${'Healthy'}         | ${'success'} | ${'Secret created or updated successfully.'}
      ${'CREATE_STALE'}       | ${'Needs attention'} | ${'danger'}  | ${'Secret creation failed. Delete the secret and try again.'}
      ${'UPDATE_STALE'}       | ${'Needs attention'} | ${'danger'}  | ${'Secret update failed. Retry the update or delete the secret.'}
      ${'CREATE_IN_PROGRESS'} | ${'Creating'}        | ${'neutral'} | ${'Secret is being created.'}
      ${'UPDATE_IN_PROGRESS'} | ${'Updating'}        | ${'neutral'} | ${'Secret is being updated.'}
    `('renders $status status', ({ status, text, tooltip, variant }) => {
      createComponent({ customSecret: { status } });

      expect(findHealthStatus().text()).toBe(text);
      expect(findHealthStatus().props('variant')).toBe(variant);
      expect(findHealthStatus().attributes('title')).toBe(tooltip);
    });
  });
});
