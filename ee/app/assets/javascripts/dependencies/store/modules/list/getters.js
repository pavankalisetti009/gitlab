import { REPORT_STATUS } from './constants';

export const isJobFailed = (state) => state.reportInfo.status === REPORT_STATUS.jobFailed;
export const isIncomplete = (state) => state.reportInfo.status === REPORT_STATUS.incomplete;
