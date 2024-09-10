import { TASKS_BY_TYPE_SUBJECT_ISSUE } from '../../../constants';

export default () => ({
  isLoading: false,

  subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
  selectedLabels: [],
  topRankedLabels: [],

  errorCode: null,
  errorMessage: '',
});
