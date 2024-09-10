export const namespaceWorkItemTypesQueryResponse = {
  data: {
    workspace: {
      id: 'gid://gitlab/Namespaces/1',
      workItemTypes: {
        nodes: [
          { id: 'gid://gitlab/WorkItems::Type/1', name: 'Issue' },
          { id: 'gid://gitlab/WorkItems::Type/2', name: 'Incident' },
          { id: 'gid://gitlab/WorkItems::Type/3', name: 'Task' },
        ],
      },
    },
  },
};

export const createWorkItemMutationResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: {
        __typename: 'WorkItem',
        id: 'gid://gitlab/WorkItem/1',
        iid: '1',
        title: 'Updated title',
        state: 'OPEN',
        description: 'description',
        confidential: false,
        createdAt: '2022-08-03T12:41:54Z',
        closedAt: null,
        webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/1',
        project: {
          __typename: 'Project',
          id: '1',
          fullPath: 'test-project-path',
          archived: false,
        },
        workItemType: {
          __typename: 'WorkItemType',
          id: 'gid://gitlab/WorkItems::Type/5',
          name: 'Task',
          iconName: 'issue-type-task',
        },
        userPermissions: {
          deleteWorkItem: false,
          updateWorkItem: false,
        },
        widgets: [],
      },
      errors: [],
    },
  },
};

export const createWorkItemMutationErrorResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: null,
      errors: ['Title is too long (maximum is 255 characters)'],
    },
  },
};

export const workItemObjectiveMetadataWidgetsEE = {
  HEALTH_STATUS: {
    type: 'HEALTH_STATUS',
    __typename: 'WorkItemWidgetHealthStatus',
    healthStatus: 'onTrack',
    rolledUpHealthStatus: [],
  },
  PROGRESS: {
    type: 'PROGRESS',
    __typename: 'WorkItemWidgetProgress',
    progress: 10,
    updatedAt: new Date(),
  },
  WEIGHT: {
    type: 'WEIGHT',
    weight: 1,
    rolledUpWeight: 0,
    widgetDefinition: {
      editable: true,
      rollUp: false,
      __typename: 'WorkItemWidgetDefinitionWeight',
    },
    __typename: 'WorkItemWidgetWeight',
  },
  ITERATION: {
    type: 'ITERATION',
    __typename: 'WorkItemWidgetIteration',
    iteration: {
      description: null,
      id: 'gid://gitlab/Iteration/1',
      iid: '12',
      title: 'Iteration title',
      startDate: '2023-12-19',
      dueDate: '2024-01-15',
      updatedAt: new Date(),
      iterationCadence: {
        title: 'Iteration 101',
        __typename: 'IterationCadence',
      },
      __typename: 'Iteration',
    },
  },
  START_AND_DUE_DATE: {
    type: 'START_AND_DUE_DATE',
    dueDate: '2024-06-27',
    startDate: '2024-01-01',
    __typename: 'WorkItemWidgetStartAndDueDate',
  },
};

export const workItemColorWidget = {
  id: 'gid://gitlab/WorkItem/1',
  iid: '1',
  title: 'Work item epic 5',
  namespace: {
    id: 'gid://gitlab/Group/1',
    fullPath: 'gitlab-org',
    name: 'Gitlab Org',
    __typename: 'Namespace',
  },
  workItemType: {
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'Epic',
    iconName: 'issue-type-epic',
    __typename: 'WorkItemType',
  },
  widgets: [
    {
      color: '#1068bf',
      textColor: '#FFFFFF',
      type: 'COLOR',
      __typename: 'WorkItemWidgetColor',
    },
  ],
  __typename: 'WorkItem',
};

export const workItemParent = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/1',
    },
  },
};

export const mockRolledUpHealthStatus = [
  {
    count: 1,
    healthStatus: 'onTrack',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 0,
    healthStatus: 'needsAttention',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
  {
    count: 1,
    healthStatus: 'atRisk',
    __typename: 'WorkItemWidgetHealthStatusCount',
  },
];
