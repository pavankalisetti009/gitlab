import { duoChatGlobalState } from '~/super_sidebar/constants';

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * @param {question} String - Prompt to send to the chat endpoint
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 */
export const sendDuoChatCommand = ({ question, resourceId, variables = {} } = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }
  if (!duoChatGlobalState.isShown) {
    duoChatGlobalState.isShown = true;
  }

  window.requestIdleCallback(() => {
    duoChatGlobalState.commands.push({
      question,
      resourceId,
      variables,
    });
  });
};

export const clearDuoChatCommands = () => {
  duoChatGlobalState.commands = [];
};

/**
 * Converts a text string into a URL-friendly format for event tracking.
 *
 * - Converts to lowercase
 * - Removes special characters
 * - Replaces spaces with underscores
 * - Limits length to 50 characters
 *
 * @param {string} text - The text to convert
 * @returns {string} The formatted event label
 */
export const generateEventLabelFromText = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
};

export const utils = {
  concatStreamedChunks,
  generateEventLabelFromText,
};
