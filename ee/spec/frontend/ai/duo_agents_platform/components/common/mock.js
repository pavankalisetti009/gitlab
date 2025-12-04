export const mockItems = [
  {
    id: 1,
    content: 'Starting workflow',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:00:00Z',
  },
  {
    id: 2,
    content: 'Processing data',
    messageType: 'assistant',
    status: 'success',
    timestamp: '2023-01-01T10:05:00Z',
  },
  {
    id: 3,
    content: 'Workflow completed',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:10:00Z',
  },
];

export const mockItemsWithFilepath = [
  {
    id: 1,
    content: 'Starting workflow',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:00:00Z',
    toolInfo: {
      args: {
        file_path: 'src/components/example.vue',
      },
    },
  },
  {
    id: 2,
    content: 'Processing data',
    messageType: 'assistant',
    status: 'success',
    timestamp: '2023-01-01T10:05:00Z',
  },
  {
    id: 3,
    content: 'File updated',
    messageType: 'tool',
    status: 'success',
    timestamp: '2023-01-01T10:10:00Z',
    toolInfo: {
      args: {
        file_path: 'src/utils/helper.js',
      },
    },
  },
];
