import { TASKS_BY_TYPE_FILTERS } from 'ee/analytics/cycle_analytics/constants';
import * as types from 'ee/analytics/cycle_analytics/store/modules/type_of_work/mutation_types';
import mutations from 'ee/analytics/cycle_analytics/store/modules/type_of_work/mutations';
import { groupLabels } from '../../../mock_data';

let state = null;

describe('Value Stream Analytics mutations', () => {
  beforeEach(() => {
    state = {};
  });

  afterEach(() => {
    state = null;
  });

  it.each`
    mutation                                         | stateKey             | value
    ${types.REQUEST_TOP_RANKED_GROUP_LABELS}         | ${'topRankedLabels'} | ${[]}
    ${types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR}   | ${'topRankedLabels'} | ${[]}
    ${types.REQUEST_TOP_RANKED_GROUP_LABELS}         | ${'selectedLabels'}  | ${[]}
    ${types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR}   | ${'selectedLabels'}  | ${[]}
    ${types.REQUEST_TOP_RANKED_GROUP_LABELS}         | ${'errorCode'}       | ${null}
    ${types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS} | ${'errorCode'}       | ${null}
    ${types.REQUEST_TOP_RANKED_GROUP_LABELS}         | ${'errorMessage'}    | ${''}
    ${types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS} | ${'errorMessage'}    | ${''}
  `('$mutation will set $stateKey=$value', ({ mutation, stateKey, value }) => {
    mutations[mutation](state);

    expect(state[stateKey]).toEqual(value);
  });

  describe(`${types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS}`, () => {
    it('sets selectedLabels to an array of label ids', () => {
      mutations[types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS](state, groupLabels);

      expect(state.selectedLabels).toEqual(groupLabels);
    });
  });

  describe(`${types.SET_TASKS_BY_TYPE_FILTERS}`, () => {
    it('will update the tasksByType state key', () => {
      state = {};
      const subjectFilter = { filter: TASKS_BY_TYPE_FILTERS.SUBJECT, value: 'cool-subject' };
      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, subjectFilter);

      expect(state.subject).toEqual('cool-subject');
    });

    it('will toggle the specified label title in the selectedLabels state key', () => {
      state = {
        selectedLabels: groupLabels,
      };
      const [first, second, third] = groupLabels;
      const labelFilter = { filter: TASKS_BY_TYPE_FILTERS.LABEL, value: second };
      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, labelFilter);

      expect(state.selectedLabels).toEqual([first, third]);

      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, labelFilter);
      expect(state.selectedLabels).toEqual([first, third, second]);
    });
  });
});
