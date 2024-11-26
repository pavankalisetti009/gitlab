import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';

import {
  workItemResponseFactory,
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

  const workItemWithMRListOnly = workItemResponseFactory({
    developmentWidgetPresent: true,
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: workItemDevelopmentMRNodes,
      willAutoCloseByMergeRequest: true,
      featureFlagNodes: [],
      branchNodes: [],
    }),
  });

  const workItemWithFlagListOnly = workItemResponseFactory({
    developmentWidgetPresent: true,
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: workItemDevelopmentFeatureFlagNodes,
      branchNodes: [],
    }),
    canUpdate: true,
  });

  const workItemWithBranchListOnly = workItemResponseFactory({
    developmentWidgetPresent: true,
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: [],
      branchNodes: workItemRelatedBranchNodes,
    }),
    canUpdate: true,
  });

  const workItemWithNoDevItems = workItemResponseFactory({
    developmentWidgetPresent: true,
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: [],
      willAutoCloseByMergeRequest: false,
      featureFlagNodes: [],
      branchNodes: [],
    }),
    canUpdate: true,
  });

  const workItemWithAllDevItems = workItemResponseFactory({
    developmentWidgetPresent: true,
    developmentItems: workItemDevelopmentFragmentResponse({
      mrNodes: workItemDevelopmentMRNodes,
      willAutoCloseByMergeRequest: true,
      featureFlagNodes: workItemDevelopmentFeatureFlagNodes,
      branchNodes: workItemRelatedBranchNodes,
    }),
  });

  const successQueryHandler = jest.fn().mockResolvedValue({
    data: {
      workspace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        workItem: workItemWithFlagListOnly.data.workItem,
      },
    },
  });

  const successQueryHandlerWithOnlyMRList = jest.fn().mockResolvedValue({
    data: {
      workspace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        workItem: workItemWithMRListOnly.data.workItem,
      },
    },
  });

  const successQueryHandlerWithOnlyBranchList = jest.fn().mockResolvedValue({
    data: {
      workspace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        workItem: workItemWithBranchListOnly.data.workItem,
      },
    },
  });

  const successQueryHandlerWithNoDevItem = jest.fn().mockResolvedValue({
    data: {
      workspace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        workItem: workItemWithNoDevItems.data.workItem,
      },
    },
  });

  const successQueryHandlerWithAllDevItemsList = jest.fn().mockResolvedValue({
    data: {
      workspace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        workItem: workItemWithAllDevItems.data.workItem,
      },
    },
  });

  const createComponent = ({
    workItemId = 'gid://gitlab/WorkItem/1',
    workItemIid = '1',
    workItemFullPath = 'full-path',
    workItemQueryHandler = successQueryHandler,
    workItemsAlphaEnabled = true,
  } = {}) => {
    mockApollo = createMockApollo([[workItemByIidQuery, workItemQueryHandler]]);

    wrapper = shallowMountExtended(WorkItemDevelopment, {
      apolloProvider: mockApollo,
      directives: {
        GlModal: createMockDirective('gl-modal'),
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        workItemId,
        workItemIid,
        workItemFullPath,
      },
      provide: {
        glFeatures: {
          workItemsAlpha: workItemsAlphaEnabled,
        },
      },
    });
  };

  const findRelationshipList = () => wrapper.findComponent(WorkItemDevelopmentRelationshipList);
  const findCreateMRButton = () => wrapper.findByTestId('create-mr-button');
  const findCreateBranchButton = () => wrapper.findByTestId('create-branch-button');

  describe('when the list of MRs is empty but there is a Feature Flag list', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag enabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandler,
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandler,
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
        workItemQueryHandler: successQueryHandlerWithOnlyMRList,
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandlerWithOnlyMRList,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  describe('when both the list of Feature flags and MRs are empty', () => {
    it(`shows 'Create MR' and 'Create branch' buttons when flag enabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandlerWithNoDevItem,
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(true);
      expect(findCreateBranchButton().exists()).toBe(true);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandlerWithNoDevItem,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  describe('when both the list of Feature flags and MRs exist', () => {
    it(`hides 'Create MR' and 'Create branch' buttons when flag enabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandlerWithAllDevItemsList,
        workItemsAlphaEnabled: true,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });

    it(`hides 'Create MR' and 'Create branch' buttons when flag disabled`, async () => {
      createComponent({
        workItemQueryHandler: successQueryHandlerWithAllDevItemsList,
        workItemsAlphaEnabled: false,
      });
      await waitForPromises();

      expect(findCreateMRButton().exists()).toBe(false);
      expect(findCreateBranchButton().exists()).toBe(false);
    });
  });

  it.each`
    description        | successQueryResolveHandler
    ${'feature flags'} | ${successQueryHandler}
    ${'MRs'}           | ${successQueryHandlerWithOnlyMRList}
    ${'branches'}      | ${successQueryHandlerWithOnlyBranchList}
  `(
    'should show the relationship list when there is only a list of $description',
    async ({ successQueryResolveHandler }) => {
      createComponent({
        workItemQueryHandler: successQueryResolveHandler,
      });
      await waitForPromises();

      expect(findRelationshipList().exists()).toBe(true);
    },
  );
});
