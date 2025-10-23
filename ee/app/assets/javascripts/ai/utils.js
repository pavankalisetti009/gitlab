import { duoChatGlobalState } from '~/super_sidebar/constants';
import { setCookie, getCookie } from '~/lib/utils/common_utils';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';

// Initialize chatMode from cookie on module load
const savedMode = getCookie(DUO_AGENTIC_MODE_COOKIE);
if (savedMode === 'true') {
  duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
} else {
  duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
}

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * setCookie wrapper with duo agentic mode constances.
 *
 * @param {isAgenticMode} Boolean - Value to save
 * @returns {void}
 */
export const saveDuoAgenticModePreference = (isAgenticMode) => {
  setCookie(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
    expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  });
};

/**
 * Switch duo chat based on agenticMode value and save to cookie based on
 * saveCookie value.
 *
 * @param {Object} params - The parameters object.
 * @param {boolean} params.agenticMode - The state of the agentic mode (true or false).
 * @param {boolean} params.saveCookie - Flag to save to cookie (true or false).
 * @param {boolean} params.isEmbedded - Flag to indicate if the chat is embedded (true or false).
 * @returns {void}
 */

export const setAgenticMode = ({
  agenticMode = true,
  saveCookie = false,
  isEmbedded = false,
} = {}) => {
  // Update the single source of truth for chat mode
  duoChatGlobalState.chatMode = agenticMode ? CHAT_MODES.AGENTIC : CHAT_MODES.CLASSIC;

  // For drawer mode, also update the legacy isShown/isAgenticChatShown properties
  if (!isEmbedded) {
    duoChatGlobalState.isShown = !agenticMode;
    duoChatGlobalState.isAgenticChatShown = agenticMode;
  }

  if (saveCookie) {
    saveDuoAgenticModePreference(agenticMode);
  }
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * External triggers always force classic mode and open the chat in whatever
 * UI mode is currently active (drawer or embedded).
 *
 * @param {question} String - Prompt to send to the chat endpoint
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 */
export const sendDuoChatCommand = ({ question, resourceId, variables = {} } = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }

  // Check if project studio (new design with embedded panel) is enabled
  const isEmbedded = window.gon?.features?.projectStudioEnabled === true;

  // External triggers always force classic mode
  setAgenticMode({ agenticMode: false, saveCookie: true, isEmbedded });

  if (isEmbedded) {
    // Embedded mode: Open the AI panel to chat tab
    duoChatGlobalState.activeTab = 'chat';
  } else {
    // Drawer mode: Open classic chat
    duoChatGlobalState.isShown = true;
    duoChatGlobalState.isAgenticChatShown = false;
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
