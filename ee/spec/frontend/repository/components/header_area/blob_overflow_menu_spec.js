import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import ceBlobOverflowMenu from '~/repository/components/header_area/blob_overflow_menu.vue';
import BlobOverflowMenu from 'ee_component/repository/components/header_area/blob_overflow_menu.vue';
import BlobButtonGroup from 'ee_else_ce/repository/components/header_area/blob_button_group.vue';
import BlobDeleteFileGroup from '~/repository/components/header_area/blob_delete_file_group.vue';
import {
  blobControlsDataMock,
  refMock,
  getProjectMockWithOverrides,
} from 'ee_else_ce_jest/repository/mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/utils/common_utils', () => ({
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('EE Blob Overflow Menu', () => {
  let wrapper;
  let fakeApollo;

  const projectPath = '/some/project';

  const createComponent = ({ projectInfoResolver, provide = {} } = {}) => {
    fakeApollo = createMockApollo([[projectInfoQuery, projectInfoResolver]]);

    wrapper = shallowMountExtended(BlobOverflowMenu, {
      apolloProvider: fakeApollo,
      provide: {
        blobInfo: blobControlsDataMock.repository.blobs.nodes[0],
        currentRef: refMock,
        rootRef: 'main',
        ...provide,
      },
      propsData: {
        isBinary: false,
        isEmptyRepository: false,
        isUsingLfs: false,
        projectPath,
      },
      stubs: {
        ceBlobOverflowMenu,
      },
    });
  };

  const findBlobButtonGroup = () => wrapper.findComponent(BlobButtonGroup);
  const findBlobDeleteFileGroup = () => wrapper.findComponent(BlobDeleteFileGroup);

  describe('canModifyFile', () => {
    beforeEach(() => {
      window.gon.current_user_name = 'root';
    });

    describe('when on default branch', () => {
      it.each`
        scenario                                            | username   | pushCode | pathLockNodes | expectedDisabled | expectedCanLock | expectedIsReplaceDisabled | expectedIsLocked
        ${'user cannot push code'}                          | ${'root'}  | ${false} | ${null}       | ${true}          | ${false}        | ${true}                   | ${true}
        ${'user can push code and no lock'}                 | ${'root'}  | ${true}  | ${[]}         | ${false}         | ${true}         | ${false}                  | ${false}
        ${'user can push code with own lock'}               | ${'root'}  | ${true}  | ${null}       | ${false}         | ${true}         | ${false}                  | ${true}
        ${'user can push code with lock from another user'} | ${'homer'} | ${true}  | ${null}       | ${true}          | ${false}        | ${true}                   | ${true}
      `(
        'returns correct values when $scenario',
        async ({
          username,
          pushCode,
          pathLockNodes,
          expectedDisabled,
          expectedCanLock,
          expectedIsReplaceDisabled,
          expectedIsLocked,
        }) => {
          window.gon.current_username = username;

          const projectInfoResolver = jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                accessLevel: pushCode ? 40 : 10,
                userPermissionsOverride: {
                  pushCode,
                },
                pathLockNodesOverride: pathLockNodes,
              }),
            },
          });

          createComponent({
            projectInfoResolver,
            provide: { currentRef: 'main' },
          });
          await waitForPromises();

          expect(findBlobDeleteFileGroup().props('disabled')).toBe(expectedDisabled);
          expect(findBlobButtonGroup().props()).toMatchObject({
            canLock: expectedCanLock,
            isReplaceDisabled: expectedIsReplaceDisabled,
            isLocked: expectedIsLocked,
          });
        },
      );
    });

    describe('when not on default branch', () => {
      it.each`
        scenario                                            | username   | pushCode | pathLockNodes | expectedDisabled | expectedCanLock | expectedIsReplaceDisabled | expectedIsLocked
        ${'user cannot push code'}                          | ${'root'}  | ${false} | ${null}       | ${false}         | ${false}        | ${false}                  | ${true}
        ${'user can push code and no lock'}                 | ${'root'}  | ${true}  | ${[]}         | ${false}         | ${true}         | ${false}                  | ${false}
        ${'user can push code with own lock'}               | ${'root'}  | ${true}  | ${null}       | ${false}         | ${true}         | ${false}                  | ${true}
        ${'user can push code with lock from another user'} | ${'homer'} | ${true}  | ${null}       | ${false}         | ${false}        | ${false}                  | ${true}
      `(
        'returns correct values when $scenario',
        async ({
          username,
          pushCode,
          pathLockNodes,
          expectedDisabled,
          expectedCanLock,
          expectedIsReplaceDisabled,
          expectedIsLocked,
        }) => {
          window.gon.current_username = username;

          const projectInfoResolver = jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                accessLevel: pushCode ? 40 : 10,
                userPermissionsOverride: {
                  pushCode,
                },
                pathLockNodesOverride: pathLockNodes,
              }),
            },
          });

          createComponent({
            projectInfoResolver,
            provide: { currentRef: 'some-other-branch' },
          });
          await waitForPromises();

          expect(findBlobDeleteFileGroup().props('disabled')).toBe(expectedDisabled);
          expect(findBlobButtonGroup().props()).toMatchObject({
            canLock: expectedCanLock,
            isReplaceDisabled: expectedIsReplaceDisabled,
            isLocked: expectedIsLocked,
          });
        },
      );
    });
  });
});
