import { GlModal, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableBulkActions from 'ee/geo_replicable/components/geo_replicable_bulk_actions.vue';
import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { MOCK_REPLICABLE_TYPE } from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableBulkActions', () => {
  let wrapper;

  const actionSpies = {
    initiateAllReplicableAction: jest.fn(),
  };

  const defaultState = {
    verificationEnabled: true,
    titlePlural: MOCK_REPLICABLE_TYPE,
  };

  const createComponent = ({ initialState = {} } = {}) => {
    const store = new Vuex.Store({
      state: { ...defaultState, ...initialState },
      actions: actionSpies,
    });

    wrapper = shallowMountExtended(GeoReplicableBulkActions, {
      store,
      directives: {
        GlModalDirective: createMockDirective('gl-modal-directive'),
      },
      stubs: { GlModal, GlSprintf },
    });
  };

  const findResyncAllButton = () => wrapper.findByTestId('geo-resync-all');
  const findReverifyAllButton = () => wrapper.findByTestId('geo-reverify-all');
  const findGlModal = () => wrapper.findComponent(GlModal);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    describe.each`
      verificationEnabled | showResyncAll | showReverifyAll
      ${false}            | ${true}       | ${false}
      ${true}             | ${true}       | ${true}
    `('Bulk Actions', ({ verificationEnabled, showResyncAll, showReverifyAll }) => {
      beforeEach(() => {
        createComponent({ initialState: { verificationEnabled } });
      });

      it(`does ${showResyncAll ? '' : 'not '}render Resync All Button`, () => {
        expect(findResyncAllButton().exists()).toBe(showResyncAll);
      });

      it(`does ${showReverifyAll ? '' : 'not '}render Reverify All Button`, () => {
        expect(findReverifyAllButton().exists()).toBe(showReverifyAll);
      });
    });
  });

  describe('Bulk actions modal', () => {
    describe('Resync All', () => {
      beforeEach(() => {
        createComponent();
        findResyncAllButton().vm.$emit('click');
      });

      it('properly populates the modal data', () => {
        expect(findGlModal().props('title')).toBe(`Resync all ${MOCK_REPLICABLE_TYPE}`);
        expect(findGlModal().text()).toContain(`This will resync all ${MOCK_REPLICABLE_TYPE}.`);
      });

      it('dispatches initiateAllReplicableAction when confirmed', () => {
        findGlModal().vm.$emit('primary');

        expect(actionSpies.initiateAllReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          action: ACTION_TYPES.RESYNC_ALL,
        });
      });
    });

    describe('Reverify All', () => {
      beforeEach(() => {
        createComponent();
        findReverifyAllButton().vm.$emit('click');
      });

      it('properly populates the modal data', () => {
        expect(findGlModal().props('title')).toBe(`Reverify all ${MOCK_REPLICABLE_TYPE}`);
        expect(findGlModal().text()).toContain(`This will reverify all ${MOCK_REPLICABLE_TYPE}.`);
      });

      it('dispatches initiateAllReplicableAction when confirmed', () => {
        findGlModal().vm.$emit('primary');

        expect(actionSpies.initiateAllReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          action: ACTION_TYPES.REVERIFY_ALL,
        });
      });
    });
  });
});
