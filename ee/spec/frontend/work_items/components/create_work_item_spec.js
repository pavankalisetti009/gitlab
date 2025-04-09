import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import namespaceWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/namespace_work_item_types.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateWorkItem from '~/work_items/components/create_work_item.vue';
import WorkItemTitle from '~/work_items/components/work_item_title.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import WorkItemDates from 'ee/work_items/components/work_item_dates.vue';
import WorkItemCustomFields from 'ee/work_items/components/work_item_custom_fields.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC, WORK_ITEM_TYPE_ENUM_ISSUE } from '~/work_items/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import createWorkItemMutation from '~/work_items/graphql/create_work_item.mutation.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import setWindowLocation from 'helpers/set_window_location_helper';
import { resolvers } from '~/graphql_shared/issuable_client';
import {
  createWorkItemMutationResponse,
  createWorkItemQueryResponse,
  namespaceWorkItemsWithoutEpicSupport,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility', () => ({
  getParameterByName: jest.fn().mockReturnValue('22'),
  mergeUrlParams: jest.fn().mockReturnValue('/branches?state=all&search=%5Emain%24'),
  joinPaths: jest.fn(),
  setUrlParams: jest
    .fn()
    .mockReturnValue('/project/Project/-/settings/repository/branch_rules?branch=main'),
  setUrlFragment: jest.fn(),
  visitUrl: jest.fn().mockName('visitUrlMock'),
  getBaseURL: jest.fn(() => 'http://127.0.0.0:3000'),
}));

describe('EE Create work item component', () => {
  let wrapper;
  let mockApollo;

  const createWorkItemSuccessHandler = jest.fn().mockResolvedValue(createWorkItemMutationResponse);
  const workItemQuerySuccessHandler = jest.fn().mockResolvedValue(createWorkItemQueryResponse);
  const namespaceWorkItemTypesHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);

  const findHealthStatusWidget = () => wrapper.findComponent(WorkItemHealthStatus);
  const findTitleInput = () => wrapper.findComponent(WorkItemTitle);
  const findIterationWidget = () => wrapper.findComponent(WorkItemIteration);
  const findWeightWidget = () => wrapper.findComponent(WorkItemWeight);
  const findColorWidget = () => wrapper.findComponent(WorkItemColor);
  const findDatesWidget = () => wrapper.findComponent(WorkItemDates);
  const findCustomFieldsWidget = () => wrapper.findComponent(WorkItemCustomFields);

  const updateWorkItemTitle = async (title = 'Test title') => {
    findTitleInput().vm.$emit('updateDraft', title);
    await nextTick();
    await waitForPromises();
  };

  const submitCreateForm = async () => {
    wrapper.find('form').trigger('submit');
    await waitForPromises();
  };

  const createComponent = ({
    props = {},
    mutationHandler = createWorkItemSuccessHandler,
    namespaceHandler = namespaceWorkItemTypesHandler,
    workItemTypeName = WORK_ITEM_TYPE_ENUM_EPIC,
    customFieldsFeature = false,
  } = {}) => {
    mockApollo = createMockApollo(
      [
        [workItemByIidQuery, workItemQuerySuccessHandler],
        [createWorkItemMutation, mutationHandler],
        [namespaceWorkItemTypesQuery, namespaceHandler],
      ],
      resolvers,
    );

    wrapper = shallowMount(CreateWorkItem, {
      apolloProvider: mockApollo,
      propsData: {
        workItemTypeName,
        ...props,
      },
      provide: {
        fullPath: 'full-path',
        groupPath: 'group-path',
        hasIssuableHealthStatusFeature: false,
        hasIterationsFeature: true,
        hasIssueWeightsFeature: true,
        glFeatures: {
          customFieldsFeature,
        },
      },
    });
  };

  const mockCurrentUser = {
    id: 1,
    name: 'Administrator',
    username: 'root',
    avatar_url: 'avatar/url',
  };

  beforeEach(() => {
    gon.current_user_id = mockCurrentUser.id;
    gon.current_user_fullname = mockCurrentUser.name;
    gon.current_username = mockCurrentUser.username;
    gon.current_user_avatar_url = mockCurrentUser.avatar_url;
  });

  describe('Create work item widgets for Epic work item type', () => {
    beforeEach(async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_EPIC });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item color widget', () => {
      expect(findColorWidget().exists()).toBe(true);
    });

    it('renders the work item rolled up dates widget', () => {
      expect(findDatesWidget().exists()).toBe(true);
    });

    it('renders the work item custom field widget if flag is enabled', async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_EPIC, customFieldsFeature: true });
      await waitForPromises();

      expect(findCustomFieldsWidget().exists()).toBe(true);
    });

    it('does not render the work item custom field widget if flag is disabled', async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_EPIC });
      await waitForPromises();

      expect(findCustomFieldsWidget().exists()).toBe(false);
    });
  });

  describe('Create work item widgets for Issue work item type', () => {
    beforeEach(async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item iteration widget', () => {
      expect(findIterationWidget().exists()).toBe(true);
    });

    it('renders the work item weight widget', () => {
      expect(findWeightWidget().exists()).toBe(true);
    });

    it('renders the work item custom field widget if flag is enabled', async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE, customFieldsFeature: true });
      await waitForPromises();

      expect(findCustomFieldsWidget().exists()).toBe(true);
    });

    it('does not render the work item custom field widget if flag is disabled', async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE });
      await waitForPromises();

      expect(findCustomFieldsWidget().exists()).toBe(false);
    });
  });

  describe('New work item for a vulnerability', () => {
    it('when not creating a vulnerability, does not pass resolve params to mutation', async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          vulnerabilityId: null,
        }),
      });
    });

    it('when creating issue from a vulnerability', async () => {
      setWindowLocation('?vulnerability_id=22');

      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          vulnerabilityId: 'gid://gitlab/Vulnerability/22',
        }),
      });
    });
  });

  describe('Creating work item with custom fields passes correct input to mutation', () => {
    const customFieldsNamespaceWorkItemTypesResponse = {
      ...namespaceWorkItemsWithoutEpicSupport,
      widgetDefinitions: [
        ...namespaceWorkItemsWithoutEpicSupport.data.workspace.workItemTypes.nodes[0]
          .widgetDefinitions,
        {
          type: 'CUSTOM_FIELDS',
          customFieldValues: [],
          __typename: 'WorkItemWidgetDefinitionCustomFields',
        },
      ],
      __typename: 'WorkItemType',
    };

    it('when creating issue with custom field values', async () => {
      const customNamespaceWorkItemTypesHandler = jest
        .fn()
        .mockResolvedValue(customFieldsNamespaceWorkItemTypesResponse);

      createComponent({
        workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE,
        customFieldsFeature: true,
        namespaceHandler: customNamespaceWorkItemTypesHandler,
      });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          customFieldsWidget: [
            { customFieldId: '1-number', numberValue: 5 },
            { customFieldId: '1-text', textValue: 'Sample text' },
            { customFieldId: '1-select', selectedOptionIds: ['select-1'] },
            { customFieldId: '1-multi-select', selectedOptionIds: ['select-1', 'select-2'] },
          ],
        }),
      });
    });
  });
});
