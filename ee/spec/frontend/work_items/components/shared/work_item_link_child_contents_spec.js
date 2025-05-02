import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import WorkItemLinkChildContents from 'ee/work_items/components/shared/work_item_link_child_contents.vue';

import { workItemTaskEE } from '../../mock_data';

jest.mock('~/alert');

describe('WorkItemLinkChildContentsEE', () => {
  let wrapper;
  const findStatusBadgeComponent = () => wrapper.findComponent(WorkItemStatusBadge);

  const createComponent = ({
    canUpdate = true,
    childItem = workItemTaskEE,
    showLabels = true,
    workItemFullPath = 'test-project-path',
    isGroup = false,
    workItemStatusFeatureFlag = true,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemLinkChildContents, {
      propsData: {
        canUpdate,
        childItem,
        showLabels,
        workItemFullPath,
      },
      provide: {
        isGroup,
        glFeatures: {
          workItemStatusFeatureFlag,
        },
      },
    });
  };

  describe('work item status badge', () => {
    it('shows the status badge if the widget exists', () => {
      createComponent();

      expect(findStatusBadgeComponent().exists()).toBe(true);
    });

    it('does not show the badge if the widget does not exist', () => {
      createComponent({
        childItem: {
          ...workItemTaskEE,
          widgets: [],
        },
      });

      expect(findStatusBadgeComponent().exists()).toBe(false);
    });

    it('does not show the badge if the widget exists and the feature flag is disabled', () => {
      createComponent({ workItemStatusFeatureFlag: false });

      expect(findStatusBadgeComponent().exists()).toBe(false);
    });
  });
});
