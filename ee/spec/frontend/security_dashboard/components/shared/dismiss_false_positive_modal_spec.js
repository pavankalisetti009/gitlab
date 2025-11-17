import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DismissFalsePositiveModal from 'ee/security_dashboard/components/shared/dismiss_false_positive_modal.vue';
import dismissFalsePositiveFlagMutation from 'ee/security_dashboard/graphql/mutations/vulnerability_dismiss_false_positive_flag.mutation.graphql';

jest.mock('~/alert');

describe('DismissFalsePositiveModal', () => {
  let wrapper;
  let apolloMutateSpy;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerabilities::Finding/123',
  };

  const mockVulnerabilitiesQuery = 'mockQuery';

  const createComponent = (props = {}, options = {}) => {
    apolloMutateSpy = jest.fn().mockResolvedValue({});

    wrapper = shallowMountExtended(DismissFalsePositiveModal, {
      propsData: {
        vulnerability: defaultVulnerability,
        ...props,
      },
      provide: {
        vulnerabilitiesQuery: mockVulnerabilitiesQuery,
        ...options.provide,
      },
      mocks: {
        $apollo: {
          mutate: apolloMutateSpy,
        },
        $toast: {
          show: jest.fn(),
        },
        ...options.mocks,
      },
      ...options,
    });
    return wrapper;
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('modalId')).toBe('dismiss-fp-confirm-modal');
      expect(findModal().props('title')).toBe('Dismiss False Positive Flag');
      expect(findModal().props('actionPrimary')).toEqual({
        text: 'Dismiss False Positive Flag',
        attributes: {
          variant: 'danger',
        },
      });
      expect(findModal().props('actionSecondary')).toEqual({
        text: 'Cancel',
        attributes: {
          variant: 'default',
        },
      });
    });

    it('renders the modal text', () => {
      expect(findModal().text()).toContain('Dismiss false positive flag for this vulnerability?');
    });

    it('uses custom modal ID when provided', () => {
      wrapper = createComponent({ modalId: 'custom-modal-id' });
      expect(findModal().props('modalId')).toBe('custom-modal-id');
    });
  });

  describe('dismissing flag', () => {
    beforeEach(() => {
      apolloMutateSpy.mockReset();
      jest.clearAllMocks();
    });

    it('calls Apollo mutation with correct parameters when primary action is triggered', async () => {
      apolloMutateSpy.mockResolvedValue({});
      wrapper = createComponent();

      await findModal().vm.$emit('primary');

      expect(apolloMutateSpy).toHaveBeenCalledWith({
        mutation: dismissFalsePositiveFlagMutation,
        variables: {
          id: defaultVulnerability.id,
        },
        refetchQueries: [mockVulnerabilitiesQuery],
      });
    });

    it('emits success event after successful mutation', async () => {
      apolloMutateSpy.mockResolvedValue({});
      wrapper = createComponent();

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('emits success event without calling toast (toast is parent responsibility)', async () => {
      apolloMutateSpy.mockResolvedValue({});
      wrapper = createComponent(
        {},
        {
          mocks: {
            $apollo: {
              mutate: apolloMutateSpy,
            },
          },
        },
      );

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('handles case when $toast is not available', async () => {
      apolloMutateSpy.mockResolvedValue({});
      wrapper = createComponent(
        {},
        {
          mocks: {
            $apollo: {
              mutate: apolloMutateSpy,
            },
            $toast: null,
          },
        },
      );

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(wrapper.emitted('success')).toHaveLength(1);
    });

    it('does not include refetchQueries when vulnerabilitiesQuery is not provided', async () => {
      apolloMutateSpy.mockResolvedValue({});
      const customApolloSpy = jest.fn().mockResolvedValue({});

      wrapper = createComponent(
        {},
        {
          provide: {
            vulnerabilitiesQuery: null,
          },
          mocks: {
            $apollo: {
              mutate: customApolloSpy,
            },
          },
        },
      );

      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(customApolloSpy).toHaveBeenCalledWith({
        mutation: dismissFalsePositiveFlagMutation,
        variables: {
          id: defaultVulnerability.id,
        },
        refetchQueries: [],
      });
    });

    describe('when mutation fails', () => {
      const mockError = new Error('Mutation failed');

      beforeEach(async () => {
        apolloMutateSpy.mockRejectedValue(mockError);
        wrapper = createComponent(
          {},
          {
            mocks: {
              $apollo: {
                mutate: apolloMutateSpy,
              },
            },
          },
        );

        findModal().vm.$emit('primary');
        await waitForPromises();
      });

      it('creates an alert with error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong while dismissing the vulnerability.',
          captureError: true,
          error: mockError,
        });
      });

      it('emits error event', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
        expect(wrapper.emitted('error')[0]).toEqual([mockError]);
      });

      it('does not emit success event', () => {
        expect(wrapper.emitted('success')).toBe(undefined);
      });
    });
  });
});
