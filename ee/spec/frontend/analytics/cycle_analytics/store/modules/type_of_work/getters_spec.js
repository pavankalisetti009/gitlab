import { selectedLabelNames } from 'ee/analytics/cycle_analytics/store/modules/type_of_work/getters';
import { TASKS_BY_TYPE_SUBJECT_ISSUE } from 'ee/analytics/cycle_analytics/constants';
import { groupLabels, groupLabelNames } from '../../../mock_data';

const state = {
  topRankedLabels: groupLabels,
  subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
  selectedLabels: groupLabels,
};

describe('Type of work getters', () => {
  describe('selectedLabelNames', () => {
    it.each`
      getterState | expected
      ${state}    | ${groupLabelNames}
      ${{}}       | ${[]}
    `('returns an array of matching label names', ({ getterState, getterRootState, expected }) => {
      const result = selectedLabelNames(getterState, null, getterRootState);
      expect(result).toEqual(expected);
    });
  });
});
