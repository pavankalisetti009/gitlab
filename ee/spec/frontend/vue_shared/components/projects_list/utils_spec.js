import { availableGraphQLProjectActions } from 'ee/vue_shared/components/projects_list/utils';
import {
  ACTION_EDIT,
  ACTION_RESTORE,
  ACTION_DELETE,
} from '~/vue_shared/components/list_actions/constants';

const MOCK_AVAILABLE_CE_ACTIONS = [ACTION_EDIT, ACTION_DELETE];

jest.mock('~/vue_shared/components/projects_list/utils', () => ({
  availableGraphQLProjectActions: jest.fn(() => MOCK_AVAILABLE_CE_ACTIONS),
}));

describe('EE Projects list utils', () => {
  describe.each`
    userPermissions             | markedForDeletionOn | availableActions
    ${{ removeProject: false }} | ${null}             | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: false }} | ${'2024-12-31'}     | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: true }}  | ${null}             | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: true }}  | ${'2024-12-31'}     | ${[ACTION_EDIT, ACTION_RESTORE, ACTION_DELETE]}
  `(
    'availableGraphQLProjectActions',
    ({ userPermissions, markedForDeletionOn, availableActions }) => {
      it(`when userPermissions = ${JSON.stringify(userPermissions)}, markedForDeletionOn is ${markedForDeletionOn}, then availableActions = [${availableActions}] and is sorted correctly`, () => {
        expect(
          availableGraphQLProjectActions({ userPermissions, markedForDeletionOn }),
        ).toStrictEqual(availableActions);
      });
    },
  );
});
