// eslint-disable-next-line no-restricted-imports
import { s__ } from '~/locale';
import { humanize } from '~/lib/utils/text_utility';
import {
  formatAgentDefinition,
  formatAgentFlowName,
  formatAgentStatus,
  parseJsonProperty,
  getNamespaceDatasetProperties,
  getToolData,
  getMessageData,
} from 'ee/ai/duo_agents_platform/utils';

// Mock the dependencies
jest.mock('~/locale');
jest.mock('~/lib/utils/text_utility');

describe('duo_agents_platform utils', () => {
  describe('formatAgentDefinition', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent flow');
      humanize.mockImplementation((str) => str.replace(/_/g, ' '));
    });

    it('returns humanized agent definition when provided', () => {
      formatAgentDefinition('software_development');

      expect(humanize).toHaveBeenCalledWith('software_development');
    });

    it('returns default text when agent definition is undefined', () => {
      formatAgentDefinition();

      expect(humanize).toHaveBeenCalledWith('Agent flow');
    });
  });

  describe('formatAgentFlowName', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent flow');
    });

    it('formats agent flow name with definition and id', () => {
      const agentDefinition = 'software_development';
      const id = 123;

      const results = formatAgentFlowName(agentDefinition, id);

      expect(humanize).toHaveBeenCalledWith('software_development');
      expect(results).toBe('software development #123');
    });

    it('formats agent flow name with default definition when null', () => {
      const id = 456;

      const result = formatAgentFlowName(null, id);

      expect(result).toBe('Agent flow #456');
    });

    it('formats agent flow name with string id', () => {
      const agentDefinition = 'convert_to_ci';
      const id = '789';

      const result = formatAgentFlowName(agentDefinition, id);

      expect(result).toBe('convert to ci #789');
    });
  });

  describe('formatAgentStatus', () => {
    beforeEach(() => {
      s__.mockReturnValue('Unknown');
      humanize.mockImplementation((str) => str.charAt(0).toUpperCase() + str.slice(1));
    });

    it('returns humanized status when provided', () => {
      const status = 'RUNNING';

      const result = formatAgentStatus(status);

      expect(humanize).toHaveBeenCalledWith('running');
      expect(result).toBe('Running');
    });

    it('returns humanized status for completed status', () => {
      const status = 'COMPLETED';

      const result = formatAgentStatus(status);

      expect(humanize).toHaveBeenCalledWith('completed');
      expect(result).toBe('Completed');
    });

    it('returns default text when status is null', () => {
      const result = formatAgentStatus(null);

      expect(s__).toHaveBeenCalledWith('DuoAgentsPlatform|Unknown');
      expect(result).toBe('Unknown');
    });

    it('returns default text when status is undefined', () => {
      const result = formatAgentStatus(undefined);

      expect(s__).toHaveBeenCalledWith('DuoAgentsPlatform|Unknown');
      expect(result).toBe('Unknown');
    });

    it('returns default text when status is empty string', () => {
      const result = formatAgentStatus('');

      expect(s__).toHaveBeenCalledWith('DuoAgentsPlatform|Unknown');
      expect(result).toBe('Unknown');
    });

    it('handles mixed case status', () => {
      const status = 'Failed';

      const result = formatAgentStatus(status);

      expect(humanize).toHaveBeenCalledWith('failed');
      expect(result).toBe('Failed');
    });
  });

  describe('parseJsonProperty', () => {
    it('parses valid JSON string', () => {
      expect(parseJsonProperty('{"key": "value"}')).toEqual({ key: 'value' });
      expect(parseJsonProperty('["0", "1", "2"]')).toEqual(['0', '1', '2']);
    });

    it('returns original value for invalid JSON string', () => {
      expect(parseJsonProperty('invalid json')).toBe('invalid json');
    });

    it('returns non-string values unchanged', () => {
      expect(parseJsonProperty(123)).toBe(123);
      expect(parseJsonProperty(null)).toBe(null);
    });
  });

  describe('getNamespaceDatasetProperties', () => {
    it('returns object with specified properties from dataset', () => {
      const dataset = {
        prop1: 'value1',
        prop2: 'value2',
        prop3: 'value3',
        unwanted: 'unwanted',
      };
      const properties = ['prop1', 'prop3'];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({
        prop1: 'value1',
        prop3: 'value3',
      });
    });

    it('returns empty object when no properties specified', () => {
      const dataset = { prop1: 'value1' };
      const properties = [];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({});
    });

    it('handles undefined properties in dataset', () => {
      const dataset = { prop1: 'value1' };
      const properties = ['prop1', 'nonexistent'];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({
        prop1: 'value1',
        nonexistent: undefined,
      });
    });

    it('parses JSON properties when specified', () => {
      const dataset = {
        normalProp: 'value1',
        jsonProp: '["0", "1", "2"]',
      };
      const properties = ['normalProp'];
      const jsonProperties = ['jsonProp'];

      const result = getNamespaceDatasetProperties(dataset, properties, jsonProperties);

      expect(result).toEqual({
        normalProp: 'value1',
        jsonProp: ['0', '1', '2'],
      });
    });
  });

  describe('getToolData', () => {
    beforeEach(() => {
      s__.mockImplementation((key) => key.split('|')[1]);
    });

    it.each([
      ['read_file', { icon: 'eye', title: 'Read file', level: 0 }],
      ['write_file', { icon: 'pencil', title: 'Write file', level: 1 }],
      ['edit_file', { icon: 'pencil', title: 'Edit file', level: 1 }],
      ['create_file_with_contents', { icon: 'pencil', title: 'Create file', level: 1 }],
      ['grep_files', { icon: 'search', title: 'Search files', level: 0 }],
      ['list_files', { icon: 'search', title: 'List files', level: 0 }],
      ['gitlab_issue_search', { icon: 'search', title: 'Search issues', level: 0 }],
      ['get_issue', { icon: 'issue-type-issue', title: 'Get issue', level: 0 }],
      ['create_merge_request', { icon: 'git-merge', title: 'Create merge request', level: 1 }],
      ['list_issue_notes', { icon: 'issue-type-issue', title: 'List comments', level: 0 }],
      ['create_commit', { icon: 'commit', title: 'Create commit', level: 1 }],
    ])('returns correct data for %s tool', (toolName, expected) => {
      const toolMessage = { tool_info: { name: toolName } };

      const result = getToolData(toolMessage);

      expect(result).toEqual(expected);
    });

    it('returns default data for unknown tool', () => {
      const toolMessage = { tool_info: { name: 'unknown_tool' } };

      const result = getToolData(toolMessage);

      expect(result).toEqual({
        icon: 'issue-type-maintenance',
        title: 'Action',
        level: 0,
      });
    });

    it('handles missing tool_info', () => {
      const toolMessage = {};

      const result = getToolData(toolMessage);

      expect(result).toEqual({
        icon: 'issue-type-maintenance',
        title: 'Action',
        level: 0,
      });
    });

    it('handles null toolMessage', () => {
      const result = getToolData(null);

      expect(result).toEqual({
        icon: 'issue-type-maintenance',
        title: 'Action',
        level: 0,
      });
    });
  });

  describe('getMessageData', () => {
    beforeEach(() => {
      s__.mockImplementation((key) => key.split('|')[1]);
    });

    it.each([
      ['user', { icon: 'user', title: 'User messaged agent', level: 1 }],
      ['request', { icon: 'question-o', title: 'Agent required human input', level: 1 }],
      ['agent', { icon: 'tanuki-ai', title: 'Agent reasoning', level: 0 }],
      ['unknown', { icon: 'issue-type-maintenance', title: 'Action', level: 0 }],
    ])('returns correct data for %s message type', (messageType, expected) => {
      const message = { message_type: messageType };

      const result = getMessageData(message);

      expect(result).toEqual(expected);
    });

    it('returns tool data for tool message type', () => {
      const message = {
        message_type: 'tool',
        tool_info: { name: 'read_file' },
      };

      const result = getMessageData(message);

      expect(result).toEqual({
        icon: 'eye',
        title: 'Read file',
        level: 0,
      });
    });

    it.each([
      [{}, "Message requires property 'message_type' but got {}"],
      [
        { message_type: null },
        'Message requires property \'message_type\' but got {"message_type":null}',
      ],
    ])('throws error when message_type is invalid: %p', (message, expectedError) => {
      expect(() => getMessageData(message)).toThrow(expectedError);
    });
  });
});
