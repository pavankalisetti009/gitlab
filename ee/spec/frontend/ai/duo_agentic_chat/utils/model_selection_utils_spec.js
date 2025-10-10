import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY } from 'ee/ai/constants';
import {
  getModel,
  getDefaultModel,
  getSavedModel,
  getCurrentModel,
  saveModel,
  clearSavedModel,
  isModelSelectionDisabled,
} from 'ee/ai/duo_agentic_chat/utils/model_selection_utils';

describe('model_selection_utils', () => {
  useLocalStorageSpy();

  const MOCK_AVAILABLE_MODELS = [
    { text: 'Claude Sonnet 4.0', value: GITLAB_DEFAULT_MODEL },
    { text: 'Claude 3.5 Sonnet', value: 'anthropic/claude-3.5-sonnet' },
    { text: 'GPT-4', value: 'openai/gpt-4' },
  ];

  const MOCK_DEFAULT_MODEL = MOCK_AVAILABLE_MODELS[0];
  const MOCK_CUSTOM_MODEL = MOCK_AVAILABLE_MODELS[1];

  describe('getModel', () => {
    it('returns the model with matching value', () => {
      const result = getModel(MOCK_AVAILABLE_MODELS, 'anthropic/claude-3.5-sonnet');

      expect(result).toEqual(MOCK_CUSTOM_MODEL);
    });
  });

  describe('getDefaultModel', () => {
    it('returns the model with GITLAB_DEFAULT_MODEL value', () => {
      const result = getDefaultModel(MOCK_AVAILABLE_MODELS);

      expect(result).toEqual(MOCK_DEFAULT_MODEL);
    });
  });

  describe('getSavedModel', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    describe('when saved model exists in available models', () => {
      it('returns the saved model', () => {
        localStorage.setItem(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );

        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toEqual(MOCK_CUSTOM_MODEL);
      });
    });

    describe('when saved model is not in available models', () => {
      it('returns null and clears localStorage', () => {
        const deletedModel = { text: 'Deleted Model', value: 'deleted/model' };
        localStorage.setItem(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY, JSON.stringify(deletedModel));

        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toBeNull();
        expect(localStorage.removeItem).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY);
      });
    });

    describe('when localStorage is empty', () => {
      it('returns null', () => {
        const result = getSavedModel(MOCK_AVAILABLE_MODELS);

        expect(result).toBeNull();
      });
    });
  });

  describe('getCurrentModel', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    describe('when isLoading is true', () => {
      it('returns null', () => {
        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel: MOCK_CUSTOM_MODEL,
          isLoading: true,
        });

        expect(result).toBeNull();
      });
    });

    describe('when pinnedModel is available', () => {
      it('returns pinnedModel', () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };
        localStorage.setItem(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );

        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel,
          selectedModel: MOCK_CUSTOM_MODEL,
          isLoading: false,
        });

        expect(result).toEqual(pinnedModel);
      });
    });

    describe('when no pinnedModel', () => {
      it('returns selectedModel', () => {
        localStorage.setItem(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );

        const selectedModel = MOCK_AVAILABLE_MODELS[2];
        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel,
          isLoading: false,
        });

        expect(result).toEqual(selectedModel);
      });
    });

    describe('when no pinnedModel or selectedModel', () => {
      it('returns saved model from localStorage', () => {
        localStorage.setItem(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );

        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel: null,
          isLoading: false,
        });

        expect(result).toEqual(MOCK_CUSTOM_MODEL);
      });
    });

    describe('when no other options available', () => {
      it('returns default model', () => {
        const result = getCurrentModel({
          availableModels: MOCK_AVAILABLE_MODELS,
          pinnedModel: null,
          selectedModel: null,
          isLoading: false,
        });

        expect(result).toEqual(MOCK_DEFAULT_MODEL);
      });
    });
  });

  describe('saveModel', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    describe('when successful', () => {
      it('saves the model to localStorage and returns true', () => {
        const result = saveModel(MOCK_CUSTOM_MODEL);

        expect(result).toBe(true);
        expect(localStorage.setItem).toHaveBeenCalledWith(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );
      });
    });

    describe('when localStorage.setItem throws an error', () => {
      it('returns false', () => {
        localStorage.setItem.mockImplementation(() => {
          throw new Error('QuotaExceededError');
        });

        const result = saveModel(MOCK_CUSTOM_MODEL);

        expect(result).toBe(false);
      });
    });
  });

  describe('clearSavedModel', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    describe('when successful', () => {
      it('removes the model from localStorage and returns true', () => {
        localStorage.setItem(
          DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY,
          JSON.stringify(MOCK_CUSTOM_MODEL),
        );

        const result = clearSavedModel();

        expect(result).toBe(true);
        expect(localStorage.removeItem).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_SELECTED_MODEL_KEY);
      });
    });

    describe('when localStorage.removeItem throws an error', () => {
      it('returns false', () => {
        localStorage.removeItem.mockImplementation(() => {
          throw new Error('Storage error');
        });

        const result = clearSavedModel();

        expect(result).toBe(false);
      });
    });
  });

  describe('isModelSelectionDisabled', () => {
    describe('when pinnedModel is provided', () => {
      it('returns true', () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };

        const result = isModelSelectionDisabled(pinnedModel);

        expect(result).toBe(true);
      });
    });

    describe('when pinnedModel is not provided', () => {
      it('returns false', () => {
        const result = isModelSelectionDisabled(undefined);

        expect(result).toBe(false);
      });
    });
  });
});
