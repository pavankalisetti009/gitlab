import {
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/vue_shared/components/groups_list/utils';
import { deleteParams, renderDeleteSuccessToast } from 'ee/vue_shared/components/groups_list/utils';
import toast from '~/vue_shared/plugins/global_toast';

const MOCK_CE_PARAMS = { ceParam: true };

jest.mock('~/vue_shared/components/groups_list/utils', () => ({
  ...jest.requireActual('~/vue_shared/components/groups_list/utils'),
  renderDeleteSuccessToast: jest.fn(),
  deleteParams: jest.fn(() => MOCK_CE_PARAMS),
}));
jest.mock('~/vue_shared/plugins/global_toast');

const MOCK_GROUP_NO_DELAY_DELETION = {
  fullName: 'No Delay Group',
  fullPath: 'path/to/group/1',
  isAdjournedDeletionEnabled: false,
  markedForDeletionOn: null,
  permanentDeletionDate: null,
};

const MOCK_GROUP_WITH_DELAY_DELETION = {
  fullName: 'With Delay Group',
  fullPath: 'path/to/group/2',
  isAdjournedDeletionEnabled: true,
  markedForDeletionOn: null,
  permanentDeletionDate: '2024-03-31',
};

const MOCK_GROUP_PENDING_DELETION = {
  fullName: 'Pending Deletion Group',
  fullPath: 'path/to/group/3',
  isAdjournedDeletionEnabled: true,
  markedForDeletionOn: '2024-03-24',
  permanentDeletionDate: '2024-03-31',
};

describe('renderDeleteSuccessToast', () => {
  it('when delayed deletion is disabled, calls renderDeleteSuccessToastCE', () => {
    renderDeleteSuccessToast(MOCK_GROUP_NO_DELAY_DELETION);

    expect(renderDeleteSuccessToastCE).toHaveBeenCalledWith(MOCK_GROUP_NO_DELAY_DELETION);
    expect(toast).not.toHaveBeenCalled();
  });

  it('when delayed deletion is enabled and project is not pending deletion, calls toast with pending deletion info', () => {
    renderDeleteSuccessToast(MOCK_GROUP_WITH_DELAY_DELETION);

    expect(renderDeleteSuccessToastCE).not.toHaveBeenCalled();
    expect(toast).toHaveBeenCalledWith(
      `Group '${MOCK_GROUP_WITH_DELAY_DELETION.fullName}' will be deleted on ${MOCK_GROUP_WITH_DELAY_DELETION.permanentDeletionDate}.`,
    );
  });

  it('when delayed deletion is enabled and project is already pending deletion, calls renderDeleteSuccessToastCE', () => {
    renderDeleteSuccessToast(MOCK_GROUP_PENDING_DELETION);

    expect(renderDeleteSuccessToastCE).toHaveBeenCalledWith(MOCK_GROUP_PENDING_DELETION);
    expect(toast).not.toHaveBeenCalled();
  });
});

describe('deleteParams', () => {
  it('when delayed deletion is disabled, returns deleteParamsCE', () => {
    const res = deleteParams(MOCK_GROUP_NO_DELAY_DELETION);

    expect(deleteParamsCE).toHaveBeenCalled();
    expect(res).toStrictEqual(MOCK_CE_PARAMS);
  });

  it('when delayed deletion is enabled and project is not pending deletion, returns deleteParamsCE', () => {
    const res = deleteParams(MOCK_GROUP_WITH_DELAY_DELETION);

    expect(deleteParamsCE).toHaveBeenCalled();
    expect(res).toStrictEqual(MOCK_CE_PARAMS);
  });

  it('when delayed deletion is enabled and project is already pending deletion, returns permanent deletion params', () => {
    const res = deleteParams(MOCK_GROUP_PENDING_DELETION);

    expect(deleteParamsCE).not.toHaveBeenCalled();
    expect(res).toStrictEqual({
      permanently_remove: true,
    });
  });
});
