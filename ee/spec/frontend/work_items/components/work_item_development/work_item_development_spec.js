import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { map } from 'lodash';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemDevelopmentQuery from '~/work_items/graphql/work_item_development.query.graphql';
import workItemDevelopmentUpdatedSubscription from '~/work_items/graphql/work_item_development.subscription.graphql';
import waitForPromises from 'helpers/wait_for_promises';

import {
  workItemByIidResponseFactory,
  workItemDevelopmentResponse,
  workItemDevelopmentFragmentResponse,
  workItemDevelopmentMRNodes,
  workItemDevelopmentFeatureFlagNodes,
  workItemRelatedBranchNodes,
} from 'jest/work_items/mock_data';

import WorkItemDevelopment from '~/work_items/components/work_item_development/work_item_development.vue';
import WorkItemDevelopmentRelationshipList from '~/work_items/components/work_item_development/work_item_development_relationship_list.vue';

/*
  MR list is available for CE and EE
  Related feature flags is only available for EE
*/
describe('WorkItemDevelopment EE', () => {
  Vue.use(VueApollo);

  let wrapper;
  let mockApollo;

  const workItemSuccessQueryHandler = jest
    .fn()
    .mockResolvedValue(
      workItemByIidResponseFactory({ canUpdate: true, customFieldsWidgetPresent: false }),
    );

  const devWidgetWithMRListOnly = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: workItemDevelopmentMRNodes,
      willAutoCloseByMergeRequest: true,
      featureFlagNodes: [],
      branchNodes: [],
      relatedMergeRequests: [],
    }),
  });

  const devWidgetWithFlagListOnly = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: workItemDevelopmentFeatureFlagNodes,
      branchNodes: [],
      relatedMergeRequests: [],
    }),
  });

  const devWidgetWithBranchListOnly = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: [],
      branchNodes: workItemRelatedBranchNodes,
      relatedMergeRequests: [],
    }),
  });

  const devWidgetWithRelatedMRListOnly = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: [],
      branchNodes: [],
      relatedMergeRequests: map(workItemDevelopmentMRNodes, 'mergeRequest'),
    }),
  });

  const devWidgetWithNoDevItems = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: [],
      branchNodes: [],
      relatedMergeRequests: [],
    }),
  });

  const devWidgetWithWithAllDevItems = workItemDevelopmentResponse({
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: workItemDevelopmentMRNodes,
      willAutoCloseByMergeRequest: true,
      featureFlagNodes: workItemDevelopmentFeatureFlagNodes,
      branchNodes: workItemRelatedBranchNodes,
      relatedMergeRequests: map(workItemDevelopmentMRNodes, 'mergeRequest'),
    }),
  });

  const devWidgetsuccessQueryHandler = jest.fn().mockResolvedValue(devWidgetWithMRListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyMRList = jest
    .fn()
    .mockResolvedValue(devWidgetWithMRListOnly);

  const devWidgetSuccessQueryHandlerWithFlagListOnly = jest
    .fn()
    .mockResolvedValue(devWidgetWithFlagListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyRelatedMRList = jest
    .fn()
    .mockResolvedValue(devWidgetWithRelatedMRListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyBranchList = jest
    .fn()
    .mockResolvedValue(devWidgetWithBranchListOnly);

  const devWidgetSuccessQueryHandlerWithNoDevItem = jest
    .fn()
    .mockResolvedValue(devWidgetWithNoDevItems);

  const devWidgetSuccessQueryHandlerWithAllDevItemsList = jest
    .fn()
    .mockResolvedValue(devWidgetWithWithAllDevItems);

  const workItemDevelopmentUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });

  const createComponent = ({
    mountFn = mountExtended,
    workItemId = 'gid://gitlab/WorkItem/1',
    workItemIid = '1',
    workItemFullPath = 'full-path',
    workItemType = 'Issue',
    workItemQueryHandler = workItemSuccessQueryHandler,
    workItemsAlphaEnabled = true,
    workItemDevelopmentQueryHandler = devWidgetsuccessQueryHandler,
  } = {}) => {
    mockApollo = createMockApollo([
      [workItemByIidQuery, workItemQueryHandler],
      [workItemDevelopmentQuery, workItemDevelopmentQueryHandler],
      [workItemDevelopmentUpdatedSubscription, workItemDevelopmentUpdatedSubscriptionHandler],
    ]);

    wrapper = mountFn(WorkItemDevelopment, {
      apolloProvider: mockApollo,
      directives: {
        GlModal: createMockDirective('gl-modal'),
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        workItemId,
        workItemIid,
        workItemFullPath,
        workItemType,
      },
      provide: {
        glFeatures: {
          workItemsAlpha: workItemsAlphaEnabled,
        },
      },
      stubs: {
        WorkItemCreateBranchMergeRequestModal: true,
      },
    });
  };

  const findRelationshipList = () => wrapper.findComponent(WorkItemDevelopmentRelationshipList);
  const findCreateMRButton = () => wrapper.findByTestId('create-mr-button');
  const findCreateBranchButton = () => wrapper.findByTestId('create-branch-button');

  describe('when the list of MRs is empty but there is a Feature Flag list', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag enabled`, async () => {
      createComponent({
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  describe('when the list of Feature Flag is empty but there is a MR list', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag enabled`, async () => {
      createComponent({
        workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithOnlyMRList,
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithOnlyMRList,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  describe('when both the list of Feature flags and MRs are empty', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithFlagListOnly,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  describe('when both the list of Feature flags and MRs exist', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithAllDevItemsList,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  it('should not show the widget when any of the dev item is not available', async () => {
    createComponent({
      mountFn: shallowMountExtended,
      workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithNoDevItem,
    });
    await waitForPromises();

    expect(findRelationshipList().exists()).toBe(false);
  });

  it.each`
    description        | successQueryResolveHandler
    ${'feature flags'} | ${devWidgetSuccessQueryHandlerWithFlagListOnly}
    ${'MRs'}           | ${devWidgetSuccessQueryHandlerWithOnlyMRList}
    ${'branches'}      | ${devWidgetSuccessQueryHandlerWithOnlyBranchList}
    ${'related MRs'}   | ${devWidgetSuccessQueryHandlerWithOnlyRelatedMRList}
  `(
    'should show the relationship list when there is only a list of $description',
    async ({ successQueryResolveHandler }) => {
      createComponent({
        mountFn: shallowMountExtended,
        workItemDevelopmentQueryHandler: successQueryResolveHandler,
      });
      await waitForPromises();

      expect(findRelationshipList().exists()).toBe(true);
    },
  );
});
