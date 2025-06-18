import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { REPLICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import GeoReplicableItem from 'ee/geo_replicable/components/geo_replicable_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import { getStoreConfig } from 'ee/geo_replicable/store';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_REPLICABLE_BASE_PATH,
  MOCK_GRAPHQL_REGISTRY_CLASS,
} from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableItem', () => {
  let wrapper;
  const mockReplicable = MOCK_BASIC_GRAPHQL_DATA[0];
  const MOCK_NAME = `${MOCK_GRAPHQL_REGISTRY_CLASS}/${getIdFromGraphQLId(mockReplicable.id)}`;
  const MOCK_DETAILS_PATH = `${MOCK_REPLICABLE_BASE_PATH}/${getIdFromGraphQLId(mockReplicable.id)}`;

  const actionSpies = {
    initiateReplicableAction: jest.fn(),
  };

  const defaultProps = {
    registryId: mockReplicable.id,
    modelRecordId: 11,
    syncStatus: mockReplicable.state,
    lastSynced: mockReplicable.lastSyncedAt,
    lastVerified: mockReplicable.verifiedAt,
  };

  const createComponent = ({ props, state, featureFlags } = {}) => {
    const store = new Vuex.Store({
      ...getStoreConfig({
        replicableType: MOCK_REPLICABLE_TYPE,
        ...state,
      }),
      actions: actionSpies,
    });

    wrapper = shallowMountExtended(GeoReplicableItem, {
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        replicableBasePath: MOCK_REPLICABLE_BASE_PATH,
        graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS,
        glFeatures: { ...featureFlags },
      },
    });
  };

  const findGeoListItem = () => wrapper.findComponent(GeoListItem);
  const findReplicableItemModelRecordId = () => wrapper.findComponent(GlSprintf);

  describe('replicable item details path', () => {
    describe('when geoReplicablesShowView is false', () => {
      beforeEach(() => {
        createComponent({ featureFlags: { geoReplicablesShowView: false } });
      });

      it('renders GeoListItem with the correct name but no detailsPath', () => {
        expect(findGeoListItem().props('name')).toBe(MOCK_NAME);
        expect(findGeoListItem().props('detailsPath')).toBeNull();
      });
    });

    describe('when geoReplicablesShowView is true', () => {
      beforeEach(() => {
        createComponent({ featureFlags: { geoReplicablesShowView: true } });
      });

      it('renders GeoListItem with the correct name and detailsPath', () => {
        expect(findGeoListItem().props('name')).toBe(MOCK_NAME);
        expect(findGeoListItem().props('detailsPath')).toBe(MOCK_DETAILS_PATH);
      });
    });
  });

  describe('replicable item status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GeoListItem with correct statusArray prop', () => {
      const expectedState = REPLICATION_STATUS_STATES.PENDING;

      expect(findGeoListItem().props('statusArray')).toStrictEqual([
        {
          tooltip: `Replication: ${expectedState.title}`,
          icon: expectedState.icon,
          variant: expectedState.variant,
        },
      ]);
    });
  });

  describe("replicable item's time ago data", () => {
    const BASE_TIME_AGO = [
      {
        label: mockReplicable.state,
        dateString: mockReplicable.lastSyncedAt,
        defaultText: 'Unknown',
      },
      {
        label: 'Last time verified',
        dateString: mockReplicable.verifiedAt,
        defaultText: null,
      },
    ];

    describe('when verificationEnabled is false', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: false } });
      });

      it('render GeoListItem with the correct timeAgoArray prop', () => {
        const expectedTimeAgo = [
          BASE_TIME_AGO[0],
          { ...BASE_TIME_AGO[1], defaultText: 'Not applicable.' },
        ];

        expect(findGeoListItem().props('timeAgoArray')).toStrictEqual(expectedTimeAgo);
      });
    });

    describe('when verificationEnabled is true', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: true } });
      });

      it('render GeoListItem with the correct timeAgoArray prop', () => {
        const expectedTimeAgo = [BASE_TIME_AGO[0], { ...BASE_TIME_AGO[1], defaultText: 'Unknown' }];

        expect(findGeoListItem().props('timeAgoArray')).toStrictEqual(expectedTimeAgo);
      });
    });
  });

  describe('replicable item actions', () => {
    const RESYNC_ACTION = {
      id: 'geo-resync-item',
      value: ACTION_TYPES.RESYNC,
      text: 'Resync',
    };

    const REVERIFY_ACTION = {
      id: 'geo-reverify-item',
      value: ACTION_TYPES.REVERIFY,
      text: 'Reverify',
    };

    describe('when verificationEnabled is false', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: false } });
      });

      it('render GeoListItem with the correct actionsArray prop', () => {
        expect(findGeoListItem().props('actionsArray')).toStrictEqual([RESYNC_ACTION]);
      });

      it('handles resync action when `actionClicked` is emitted', async () => {
        findGeoListItem().vm.$emit('actionClicked', RESYNC_ACTION);
        await nextTick();

        expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          registryId: defaultProps.registryId,
          name: MOCK_NAME,
          action: ACTION_TYPES.RESYNC,
        });
      });
    });

    describe('when verificationEnabled is true', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: true } });
      });

      it('render GeoListItem with the correct actionsArray prop', () => {
        expect(findGeoListItem().props('actionsArray')).toStrictEqual([
          RESYNC_ACTION,
          REVERIFY_ACTION,
        ]);
      });

      it('handles reverify action when `actionClicked` is emitted', async () => {
        findGeoListItem().vm.$emit('actionClicked', REVERIFY_ACTION);
        await nextTick();

        expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          registryId: defaultProps.registryId,
          name: MOCK_NAME,
          action: ACTION_TYPES.REVERIFY,
        });
      });
    });
  });

  describe('extra details', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the model record ID in the extra details section', () => {
      expect(findReplicableItemModelRecordId().attributes('message')).toBe(
        'Model record: %{modelRecordId}',
      );
    });
  });
});
