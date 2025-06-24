<script>
import {
  GlAlert,
  GlFormGroup,
  GlCollapsibleListbox,
  GlFormCheckboxGroup,
  GlTruncate,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';

export default {
  RECENTLY_USED_TOKENS_MAX: 3,
  i18n: {
    title: s__('ScanResultPolicy|Select token exceptions'),
    description: s__(
      'ScanResultPolicy|Apply this approval rule to any branch or a specific protected branch.',
    ),
    tokensHeader: s__('ScanResultPolicy|Access tokens'),
    tokenDefaultText: s__('ScanResultPolicy|Select tokens'),
    noTokensCreated: s__('ScanResultPolicy|There are no access tokens created'),
    accessTokenTypeName: s__('ScanResultPolicy|access token'),
    securityProjectDefaultText: s__('ScanResultPolicy|Security team project'),
    frequentlyUsedHeader: s__('ScanResultPolicy|Recently created'),
    targetProjectTitle: s__('ScanResultPolicy|Target project documentation'),
    fetchingError: s__('ScanResultPolicy|Error occurred while fetching access tokens.'),
  },
  name: 'TokensSelector',
  components: {
    GlAlert,
    GlFormGroup,
    GlCollapsibleListbox,
    GlFormCheckboxGroup,
    GlTruncate,
  },
  inject: ['accessTokens'],
  props: {
    tokens: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      showAlert: false,
      searchTerm: '',
    };
  },
  computed: {
    selectedTokens() {
      return this.tokens.map(({ id }) => id);
    },
    accessTokensItems() {
      if (!Array.isArray(this.accessTokens) || this.accessTokens.length === 0) {
        return {};
      }

      return this.accessTokens?.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedTokens.map(String),
        items: this.accessTokensItems,
        itemTypeName: this.$options.i18n.accessTokenTypeName,
        useAllSelected: false,
      });
    },
    listBoxItems() {
      return (
        this.accessTokens?.map(({ name, id, full_name: fullName }) => ({
          text: name,
          value: id,
          fullName,
        })) || []
      );
    },
    filteredItems() {
      return searchInItemsProperties({
        items: this.listBoxItems,
        properties: ['text', 'value'],
        searchQuery: this.searchTerm,
      });
    },
    hasRecentlyUsedItems() {
      return this.recentlyUsedItems.length > 0;
    },
    recentlyUsedItems() {
      return this.listBoxItems.slice(0, this.$options.RECENTLY_USED_TOKENS_MAX);
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    setSearchTerm(term) {
      this.searchTerm = term;
    },
    setTokens(ids) {
      const payload = ids.map((id) => ({ id }));
      this.$emit('set-tokens', payload);
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="tokens-list"
      :optional="false"
      label-for="tokens-list"
      :label="$options.i18n.title"
      :description="$options.i18n.description"
    >
      <gl-collapsible-listbox
        block
        multiple
        class="gl-w-full"
        searchable
        :selected="selectedTokens"
        :header-text="$options.i18n.tokensHeader"
        :items="filteredItems"
        :toggle-text="toggleText"
        @search="debouncedSearch"
        @select="setTokens"
      >
        <template #list-item="{ item }">
          <span :class="['gl-block', { 'gl-font-bold': item.fullName }]">
            <gl-truncate :text="item.text" with-tooltip />
          </span>
          <span v-if="item.fullName" class="gl-mt-1 gl-block gl-text-sm gl-text-subtle">
            <gl-truncate position="middle" :text="item.fullName" with-tooltip />
          </span>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>

    <gl-alert v-if="showAlert" variant="danger" :dismissible="false">
      {{ $options.i18n.fetchingError }}
    </gl-alert>

    <div class="gl-mt-6">
      <h5 class="gl-mb-5">{{ $options.i18n.frequentlyUsedHeader }}</h5>
      <div>
        <gl-form-checkbox-group
          v-if="hasRecentlyUsedItems"
          data-testid="recently-selected-list"
          :options="recentlyUsedItems"
          :checked="selectedTokens"
          @input="setTokens"
        />
        <p v-else>
          {{ $options.i18n.noTokensCreated }}
        </p>
      </div>
    </div>
  </div>
</template>
