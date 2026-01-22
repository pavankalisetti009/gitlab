import { resolveVersion } from 'ee/ai/catalog/utils';
import { VERSION_LATEST, VERSION_PINNED, VERSION_PINNED_GROUP } from 'ee/ai/catalog/constants';

describe('AI Catalog Utils', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  /**
    Versioning utilities
   */

  const EXP_LATEST = { id: '1', name: 'Latest' };
  const EXP_PINNED_PROJECT = { id: '2', name: 'Project pinned' };
  const EXP_PINNED_GROUP = { id: '3', name: 'Group pinned' };

  describe('resolveVersion', () => {
    describe('handles when isGlobal is true correctly', () => {
      it('returns the latestVersion', () => {
        const mockItem = {
          latestVersion: EXP_LATEST,
          configurationForProject: { pinnedItemVersion: EXP_PINNED_PROJECT },
          configurationForGroup: { pinnedItemVersion: EXP_PINNED_GROUP },
        };
        const result = resolveVersion(mockItem, true);
        expect(result).toEqual({ ...EXP_LATEST, key: VERSION_LATEST });
      });
    });

    describe('prioritizes returned configuration correctly when isGlobal is false', () => {
      const PINNED_PROJECT_CONFIG = { pinnedItemVersion: EXP_PINNED_PROJECT };
      const PINNED_GROUP_CONFIG = { pinnedItemVersion: EXP_PINNED_GROUP };
      // Note that here we assert against the actual runtime constants, since these are what are returned by the resolveVersion function
      it.each`
        description                                                             | latestVersion | pinnedProjectConfig      | pinnedGroupConfig      | expectedKey             | expectedConfig
        ${'prioritizes configurationForProject over configurationForGroup'}     | ${EXP_LATEST} | ${PINNED_PROJECT_CONFIG} | ${PINNED_GROUP_CONFIG} | ${VERSION_PINNED}       | ${EXP_PINNED_PROJECT}
        ${'returns VERSION_PINNED when configurationForGroup is undefined'}     | ${EXP_LATEST} | ${PINNED_PROJECT_CONFIG} | ${undefined}           | ${VERSION_PINNED}       | ${EXP_PINNED_PROJECT}
        ${'uses configurationForGroup when configurationForProject is missing'} | ${EXP_LATEST} | ${undefined}             | ${PINNED_GROUP_CONFIG} | ${VERSION_PINNED_GROUP} | ${EXP_PINNED_GROUP}
        ${'uses VERSION_LATEST when both configurations are missing'}           | ${EXP_LATEST} | ${undefined}             | ${undefined}           | ${VERSION_LATEST}       | ${EXP_LATEST}
      `(
        '$description',
        ({
          latestVersion,
          pinnedProjectConfig,
          pinnedGroupConfig,
          expectedKey,
          expectedConfig,
        }) => {
          const testItem = {
            latestVersion,
            configurationForProject: pinnedProjectConfig,
            configurationForGroup: pinnedGroupConfig,
          };
          const result = resolveVersion(testItem, false);
          expect(result).toEqual({ ...expectedConfig, key: expectedKey });
        },
      );
    });
  });
});
