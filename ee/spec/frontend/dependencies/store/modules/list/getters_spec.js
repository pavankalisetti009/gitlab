import { REPORT_STATUS } from 'ee/dependencies/store/modules/list/constants';
import * as getters from 'ee/dependencies/store/modules/list/getters';

describe('Dependencies getters', () => {
  describe.each`
    getterName        | reportStatus                    | outcome
    ${'isJobFailed'}  | ${REPORT_STATUS.jobFailed}      | ${true}
    ${'isJobFailed'}  | ${REPORT_STATUS.noDependencies} | ${false}
    ${'isJobFailed'}  | ${REPORT_STATUS.ok}             | ${false}
    ${'isIncomplete'} | ${REPORT_STATUS.incomplete}     | ${true}
    ${'isIncomplete'} | ${REPORT_STATUS.ok}             | ${false}
  `('$getterName when report status is $reportStatus', ({ getterName, reportStatus, outcome }) => {
    it(`returns ${outcome}`, () => {
      expect(
        getters[getterName]({
          reportInfo: {
            status: reportStatus,
          },
        }),
      ).toBe(outcome);
    });
  });
});
