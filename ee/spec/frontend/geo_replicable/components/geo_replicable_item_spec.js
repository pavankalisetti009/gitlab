import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { REPLICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import GeoReplicableItem from 'ee/geo_replicable/components/geo_replicable_item.vue';
import GeoListItemStatus from 'ee/geo_shared/list/components/geo_list_item_status.vue';
import GeoListItemTimeAgo from 'ee/geo_shared/list/components/geo_list_item_time_ago.vue';
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

  const createComponent = (props = {}, state = {}, featureFlags = {}) => {
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

  const findReplicableItemHeader = () => wrapper.findByTestId('replicable-item-header');
  const findReplicableItemSyncStatus = () =>
    findReplicableItemHeader().findComponent(GeoListItemStatus);
  const findResyncButton = () => wrapper.findByTestId('geo-resync-item');
  const findReverifyButton = () => wrapper.findByTestId('geo-reverify-item');
  const findReplicableItemNoLinkText = () => findReplicableItemHeader().find('span');
  const findReplicableDetailsLink = () => wrapper.findComponent(GlLink);
  const findReplicableItemTimeAgos = () => wrapper.findAllComponents(GeoListItemTimeAgo);
  const findReplicableTimeAgosDateStrings = () =>
    findReplicableItemTimeAgos().wrappers.map((w) => w.props('dateString'));
  const findReplicableTimeAgosDefaultTexts = () =>
    findReplicableItemTimeAgos().wrappers.map((w) => w.props('defaultText'));
  const findReplicableItemModelRecordId = () => wrapper.findComponent(GlSprintf);

  describe.each`
    verificationEnabled | showResyncAction | showReverifyAction
    ${false}            | ${true}          | ${false}
    ${true}             | ${true}          | ${true}
  `('template', ({ verificationEnabled, showResyncAction, showReverifyAction }) => {
    describe(`when verificationEnabled is ${verificationEnabled}`, () => {
      beforeEach(() => {
        createComponent(null, { verificationEnabled });
      });

      it('renders GeoListItemStatus with correct props', () => {
        const expectedState = REPLICATION_STATUS_STATES.PENDING;

        expect(findReplicableItemSyncStatus().props('statusArray')).toStrictEqual([
          {
            tooltip: `Replication: ${expectedState.title}`,
            icon: expectedState.icon,
            variant: expectedState.variant,
          },
        ]);
      });

      it(`${showResyncAction ? 'does' : 'does not'} render Resync Button`, () => {
        expect(findResyncButton().exists()).toBe(showResyncAction);
      });

      it(`${showReverifyAction ? 'does' : 'does not'} render Reverify Button`, () => {
        expect(findReverifyButton().exists()).toBe(showReverifyAction);
      });
    });
  });

  describe('list item title', () => {
    describe('when geoReplicablesShowView is false', () => {
      beforeEach(() => {
        createComponent(null, null, { geoReplicablesShowView: false });
      });

      it(`renders name as plain text ${MOCK_NAME}`, () => {
        expect(findReplicableItemNoLinkText().text()).toBe(MOCK_NAME);
      });

      it('does not render a link', () => {
        expect(findReplicableDetailsLink().exists()).toBe(false);
      });
    });

    describe('when geoReplicablesShowView is true', () => {
      beforeEach(() => {
        createComponent(null, null, { geoReplicablesShowView: true });
      });

      it('does not render as plain text', () => {
        expect(findReplicableItemNoLinkText().exists()).toBe(false);
      });

      it(`renders name as link ${MOCK_NAME}`, () => {
        expect(findReplicableDetailsLink().text()).toBe(MOCK_NAME);
      });

      it('renders a link', () => {
        expect(findReplicableDetailsLink().attributes('href')).toBe(
          `${MOCK_REPLICABLE_BASE_PATH}/${getIdFromGraphQLId(mockReplicable.id)}`,
        );
      });
    });
  });

  describe('Resync button action', () => {
    beforeEach(() => {
      createComponent(null, null);
    });

    it('calls initiateReplicableAction when clicked', () => {
      findResyncButton().vm.$emit('click');

      expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
        registryId: defaultProps.registryId,
        name: MOCK_NAME,
        action: ACTION_TYPES.RESYNC,
      });
    });
  });

  describe('Reverify button action', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: true });
    });

    it('calls initiateReplicableAction when clicked', () => {
      findReverifyButton().vm.$emit('click');

      expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
        registryId: defaultProps.registryId,
        name: MOCK_NAME,
        action: ACTION_TYPES.REVERIFY,
      });
    });
  });

  describe('when verificationEnabled is true', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: 'true' });
    });

    it('renders GeoListItemTimeAgo component for each element in timeAgoArray', () => {
      expect(findReplicableItemTimeAgos().length).toBe(2);
    });

    it('passes the correct date strings to the GeoListItemTimeAgo component', () => {
      expect(findReplicableTimeAgosDateStrings().length).toBe(2);
      expect(findReplicableTimeAgosDateStrings()).toStrictEqual([
        mockReplicable.lastSyncedAt,
        mockReplicable.verifiedAt,
      ]);
    });

    it('passes the correct date defaultTexts to the GeoListItemTimeAgo component', () => {
      expect(findReplicableTimeAgosDefaultTexts().length).toBe(2);
      expect(findReplicableTimeAgosDefaultTexts()).toStrictEqual([
        GeoReplicableItem.i18n.unknown,
        GeoReplicableItem.i18n.unknown,
      ]);
    });
  });

  describe('when verificationEnabled is false', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: 'false' });
    });

    it('renders GeoListItemTimeAgo component for each element in timeAgoArray', () => {
      expect(findReplicableItemTimeAgos().length).toBe(2);
    });

    it('passes the correct date strings to the GeoListItemTimeAgo component', () => {
      expect(findReplicableTimeAgosDateStrings().length).toBe(2);
      expect(findReplicableTimeAgosDateStrings()).toStrictEqual([
        mockReplicable.lastSyncedAt,
        mockReplicable.verifiedAt,
      ]);
    });

    it('passes the correct date defaultTexts to the GeoListItemTimeAgo component', () => {
      expect(findReplicableTimeAgosDefaultTexts().length).toBe(2);
      expect(findReplicableTimeAgosDefaultTexts()).toStrictEqual([
        GeoReplicableItem.i18n.unknown,
        GeoReplicableItem.i18n.nA,
      ]);
    });
  });

  it('renders a model record id', () => {
    createComponent();

    expect(findReplicableItemModelRecordId().attributes('message')).toBe(
      'Model record: %{modelRecordId}',
    );
  });
});
