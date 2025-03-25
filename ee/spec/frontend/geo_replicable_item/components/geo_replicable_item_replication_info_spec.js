import { GlSprintf, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableItemReplicationInfo from 'ee/geo_replicable_item/components/geo_replicable_item_replication_info.vue';
import { REPLICATION_STATUS_STATES } from 'ee/geo_replicable_item//constants';
import { MOCK_REPLICABLE_WITH_VERIFICATION } from '../mock_data';

describe('GeoReplicableItemReplicationInfo', () => {
  let wrapper;

  const defaultProps = {
    replicableItem: MOCK_REPLICABLE_WITH_VERIFICATION,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableItemReplicationInfo, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findRetryAt = () => wrapper.findByTestId('retry-at-time-ago');
  const findLastSyncedAt = () => wrapper.findByTestId('last-synced-at-time-ago');

  describe.each`
    state        | badge
    ${'PENDING'} | ${REPLICATION_STATUS_STATES.PENDING}
    ${'STARTED'} | ${REPLICATION_STATUS_STATES.STARTED}
    ${'SYNCED'}  | ${REPLICATION_STATUS_STATES.SYNCED}
    ${'FAILED'}  | ${REPLICATION_STATUS_STATES.FAILED}
    ${'asdf'}    | ${REPLICATION_STATUS_STATES.UNKNOWN}
    ${null}      | ${REPLICATION_STATUS_STATES.UNKNOWN}
  `('when replication status is $state', ({ state, badge }) => {
    beforeEach(() => {
      createComponent({
        props: { replicableItem: { ...MOCK_REPLICABLE_WITH_VERIFICATION, state } },
      });
    });

    it('renders the correct badge variant', () => {
      expect(findGlBadge().text()).toBe(badge.title);
      expect(findGlBadge().props('variant')).toBe(badge.variant);
    });
  });

  describe('missing on primary', () => {
    describe('when property is true', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: { ...MOCK_REPLICABLE_WITH_VERIFICATION, missingOnPrimary: true },
          },
        });
      });

      it('render missing on primary text', () => {
        expect(wrapper.findByText('Missing on Primary!').exists()).toBe(true);
      });
    });

    describe('when property is false', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: { ...MOCK_REPLICABLE_WITH_VERIFICATION, missingOnPrimary: false },
          },
        });
      });

      it('does not render missing on primary text', () => {
        expect(wrapper.findByText('Missing on Primary!').exists()).toBe(false);
      });
    });
  });

  describe('replication failures', () => {
    describe('when state is FAILED', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              state: 'FAILED',
              lastSyncFailure: 'Something is broken',
              retryCount: 2,
              retryAt: '2025-01-01',
            },
          },
        });
      });

      it('does render error text', () => {
        expect(wrapper.text()).toContain('Error: Something is broken');
      });

      it('does not render sync retry text', () => {
        expect(wrapper.text()).toContain('Next sync retry: Retry #2 scheduled');
        expect(findRetryAt().props('time')).toBe('2025-01-01');
      });
    });

    describe('when state is not FAILED', () => {
      beforeEach(() => {
        createComponent({
          props: { replicableItem: { ...MOCK_REPLICABLE_WITH_VERIFICATION, state: 'SYNCED' } },
        });
      });

      it('does not render error text', () => {
        expect(wrapper.text()).not.toContain('Error:');
      });

      it('does not render sync retry text', () => {
        expect(wrapper.text()).not.toContain('Next sync retry:');
        expect(findRetryAt().exists()).toBe(false);
      });
    });
  });

  describe('last synced', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with TimeAgo component', () => {
      expect(wrapper.findByText('Last synced:').exists()).toBe(true);
      expect(findLastSyncedAt().props('time')).toBe(MOCK_REPLICABLE_WITH_VERIFICATION.lastSyncedAt);
    });
  });
});
