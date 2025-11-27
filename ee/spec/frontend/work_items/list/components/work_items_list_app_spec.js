import { GlEmptyState } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/pages/work_items_list_app.vue';
import {
  CREATION_CONTEXT_LIST_ROUTE,
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  WORK_ITEM_TYPE_NAME_TASK,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TITLE_HEALTH,
  TOKEN_TYPE_STATUS,
  TOKEN_TITLE_STATUS,
  TOKEN_TYPE_ITERATION,
  TOKEN_TITLE_ITERATION,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import searchIterationsQuery from 'ee/issues/list/queries/search_iterations.query.graphql';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';
import { mockNamespaceCustomFieldsResponse } from 'ee_jest/vue_shared/components/filtered_search_bar/mock_data';

const mockIterationsResponse = {
  data: {
    project: {
      iterations: {
        nodes: [
          { id: 'gid://gitlab/Iteration/1', title: 'Iteration 1' },
          { id: 'gid://gitlab/Iteration/2', title: 'Iteration 2' },
        ],
      },
    },
  },
};

/** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
let wrapper;

Vue.use(VueApollo);

const baseCustomFieldsQueryHandler = jest.fn().mockResolvedValue(mockNamespaceCustomFieldsResponse);
const iterationsQueryHandler = jest.fn().mockResolvedValue(mockIterationsResponse);

const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);

const baseProvide = {
  groupIssuesPath: 'groups/gitlab-org/-/issues',
};

const mountComponent = ({
  hasEpicsFeature = true,
  hasIssueWeightsFeature = false,
  hasIssuableHealthStatusFeature = false,
  hasCustomFieldsFeature = true,
  hasIterationsFeature = false,
  hasStatusFeature = true,
  showNewWorkItem = true,
  isGroup = true,
  workItemType = WORK_ITEM_TYPE_NAME_EPIC,
  props = {},
  customFieldsQueryHandler = baseCustomFieldsQueryHandler,
} = {}) => {
  wrapper = shallowMountExtended(EEWorkItemsListApp, {
    apolloProvider: createMockApollo([
      [namespaceCustomFieldsQuery, customFieldsQueryHandler],
      [searchIterationsQuery, iterationsQueryHandler],
    ]),
    provide: {
      hasEpicsFeature,
      hasCustomFieldsFeature,
      hasIssueWeightsFeature,
      hasIssuableHealthStatusFeature,
      hasIterationsFeature,
      showNewWorkItem,
      isGroup,
      workItemType,
      hasStatusFeature,
      ...baseProvide,
    },
    stubs: {
      EmptyStateWithoutAnyIssues: {
        template: '<div></div>',
      },
    },
    propsData: {
      rootPageFullPath: 'gitlab-org',
      ...props,
    },
  });
};

describe('create-work-item modal', () => {
  describe.each`
    hasEpicsFeature | showNewWorkItem | exists
    ${false}        | ${false}        | ${false}
    ${true}         | ${false}        | ${false}
    ${false}        | ${true}         | ${false}
    ${true}         | ${true}         | ${true}
  `(
    'when hasEpicsFeature=$hasEpicsFeature and showNewWorkItem=$showNewWorkItem',
    ({ hasEpicsFeature, showNewWorkItem, exists }) => {
      it(`${exists ? 'renders' : 'does not render'}`, () => {
        mountComponent({ hasEpicsFeature, showNewWorkItem });

        expect(findCreateWorkItemModal().exists()).toBe(exists);
      });
    },
  );

  it('passes the right props to modal when hasEpicsFeature is true', () => {
    mountComponent({ hasEpicsFeature: true, showNewWorkItem: true });

    expect(findCreateWorkItemModal().props()).toMatchObject({
      creationContext: CREATION_CONTEXT_LIST_ROUTE,
      isGroup: true,
      preselectedWorkItemType: WORK_ITEM_TYPE_NAME_EPIC,
    });
  });

  describe('when "workItemCreated" event is emitted', () => {
    it('increments `eeWorkItemUpdateCount` prop on WorkItemsListApp', async () => {
      mountComponent();

      expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(0);

      findCreateWorkItemModal().vm.$emit('workItemCreated');
      await nextTick();

      expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(1);
    });
  });
});

describe('empty states', () => {
  describe('when hasEpicsFeature=true', () => {
    beforeEach(() => {
      mountComponent({ hasEpicsFeature: true });
    });

    it('renders list empty state', () => {
      expect(findListEmptyState().props()).toEqual({
        hasSearch: false,
        isEpic: true,
        isOpenTab: true,
      });
    });

    it('renders page empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).props()).toMatchObject({
        description: 'Track groups of issues that share a theme, across projects and milestones',
        title:
          'Epics let you manage your portfolio of projects more efficiently and with less effort',
      });
    });
  });

  describe('when hasEpicsFeature=false', () => {
    beforeEach(() => {
      mountComponent({ hasEpicsFeature: false });
    });

    it('does not render list empty state', () => {
      expect(findListEmptyState().exists()).toBe(false);
    });

    it('does not render page empty state', () => {
      expect(findPageEmptyState().exists()).toBe(false);
    });
  });
});

describe('when withTabs is false', () => {
  it('passes the correct props to WorkItemsListApp', () => {
    mountComponent({ props: { withTabs: false } });

    expect(findWorkItemsListApp().props('withTabs')).toBe(false);
  });
});

describe('filter tokens', () => {
  const findToken = (type) => {
    const eeSearchTokens = findWorkItemsListApp().props('eeSearchTokens');
    return eeSearchTokens.find((token) => token.type === type);
  };

  describe('custom fields', () => {
    const mockCustomFields = mockNamespaceCustomFieldsResponse.data.namespace.customFields.nodes;
    const epicListAllowedFields = mockCustomFields.filter(
      (field) =>
        [CUSTOM_FIELDS_TYPE_SINGLE_SELECT, CUSTOM_FIELDS_TYPE_MULTI_SELECT].includes(
          field.fieldType,
        ) && field.workItemTypes.some((type) => type.name === WORK_ITEM_TYPE_NAME_EPIC),
    );
    const issueListAllowedFields = mockCustomFields.filter(
      (field) =>
        [CUSTOM_FIELDS_TYPE_SINGLE_SELECT, CUSTOM_FIELDS_TYPE_MULTI_SELECT].includes(
          field.fieldType,
        ) &&
        field.workItemTypes.some(
          (type) =>
            type.name === WORK_ITEM_TYPE_NAME_ISSUE || type.name === WORK_ITEM_TYPE_NAME_TASK,
        ),
    );
    const findCustomFieldTokens = () =>
      findWorkItemsListApp()
        .props('eeSearchTokens')
        .filter((token) => token.type.startsWith(TOKEN_TYPE_CUSTOM_FIELD));

    const getExpectedTokens = (fields) => {
      return fields.map((field) => ({
        type: `${TOKEN_TYPE_CUSTOM_FIELD}[${field.id.split('/').pop()}]`,
        title: field.name,
        icon: 'multiple-choice',
        field,
        fullPath: 'gitlab-org',
        token: expect.any(Function),
        operators: OPERATORS_IS,
        unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
      }));
    };

    it('excludes custom field tokens when feature is disabled', async () => {
      mountComponent({ hasCustomFieldsFeature: false });
      await waitForPromises();

      const customFieldTokens = findCustomFieldTokens();

      expect(customFieldTokens).toHaveLength(0);
      expect(baseCustomFieldsQueryHandler).not.toHaveBeenCalled(); // Verify query was skipped
    });

    it('includes custom field tokens when feature is enabled', async () => {
      mountComponent();
      await waitForPromises();

      const customFieldTokens = findCustomFieldTokens();

      expect(customFieldTokens).toHaveLength(2);
    });

    it('fetches custom fields when component is mounted', async () => {
      mountComponent();
      await waitForPromises();

      expect(baseCustomFieldsQueryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
        active: true,
      });
    });

    it('passes custom field tokens to WorkItemsListApp and unique field is based on field type', async () => {
      mountComponent();
      await waitForPromises();

      expect(findWorkItemsListApp().props('eeSearchTokens')).toHaveLength(2);
      expect(findWorkItemsListApp().props('eeSearchTokens')[0]).toMatchObject(
        getExpectedTokens(epicListAllowedFields)[0],
      );
      expect(findWorkItemsListApp().props('eeSearchTokens')[1]).toMatchObject(
        getExpectedTokens(epicListAllowedFields)[1],
      );
    });

    it('does not have epics custom fields token on issues list', async () => {
      mountComponent({ workItemType: null, hasStatusFeature: false });
      await waitForPromises();

      expect(findWorkItemsListApp().props('eeSearchTokens')).toHaveLength(3);

      expect(findWorkItemsListApp().props('eeSearchTokens')[0]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[0],
      );
      expect(findWorkItemsListApp().props('eeSearchTokens')[1]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[1],
      );
      expect(findWorkItemsListApp().props('eeSearchTokens')[2]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[2],
      );
    });
  });

  describe('weight', () => {
    it('excludes weight token when feature is disabled', async () => {
      mountComponent({
        hasIssueWeightsFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toBeUndefined();
    });

    it('excludes weight token when feature is enabled but on epics list', async () => {
      mountComponent({
        hasIssueWeightsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toBeUndefined();
    });

    it('includes weight token when feature is enabled and not on epics list', async () => {
      mountComponent({
        hasIssueWeightsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toMatchObject({
        type: TOKEN_TYPE_WEIGHT,
        title: TOKEN_TITLE_WEIGHT,
        icon: 'weight',
        token: expect.any(Function),
        unique: true,
      });
    });
  });

  describe('health status', () => {
    it('excludes health token when feature is disabled', async () => {
      mountComponent({
        hasIssuableHealthStatusFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const healthToken = findToken(TOKEN_TYPE_HEALTH);

      expect(healthToken).toBeUndefined();
    });

    it('includes health token for issues when feature is enabled', async () => {
      mountComponent({
        hasIssuableHealthStatusFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const healthToken = findToken(TOKEN_TYPE_HEALTH);

      expect(healthToken).toMatchObject({
        type: TOKEN_TYPE_HEALTH,
        title: TOKEN_TITLE_HEALTH,
        icon: 'status-health',
        token: expect.any(Function),
        unique: true,
      });
    });
  });

  describe('iteration', () => {
    it('excludes iteration token when feature is disabled', async () => {
      mountComponent({
        hasIterationsFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toBeUndefined();
    });

    it('excludes iteration token when feature is enabled but on epics list', async () => {
      mountComponent({
        hasIterationsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toBeUndefined();
    });

    it('includes iteration token when feature is enabled and not on epics list', async () => {
      mountComponent({
        hasIterationsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toMatchObject({
        type: TOKEN_TYPE_ITERATION,
        title: TOKEN_TITLE_ITERATION,
        icon: 'iteration',
        token: expect.any(Function),
        fetchIterations: expect.any(Function),
        recentSuggestionsStorageKey: 'gitlab-org-work-items-recent-tokens-iteration',
        fullPath: 'gitlab-org',
        isProject: false,
      });
    });
  });

  describe('status token', () => {
    it('excludes status token when feature is disabled and group work items list', async () => {
      mountComponent({
        hasStatusFeature: false,
        isGroup: true,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toBeUndefined();
    });

    it('includes status token when feature is enabled and group work item lists', async () => {
      mountComponent({
        hasStatusFeature: true,
        isGroup: true,
        workItemType: null,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toMatchObject({
        type: TOKEN_TYPE_STATUS,
        title: TOKEN_TITLE_STATUS,
        icon: 'status',
        token: WorkItemStatusToken,
        unique: true,
      });
    });

    it('excludes status token when feature is enabled and epic lists', async () => {
      mountComponent({
        hasStatusFeature: true,
        isGroup: true,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toBeUndefined();
    });
  });
});
