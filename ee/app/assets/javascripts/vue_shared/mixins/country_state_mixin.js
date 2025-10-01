import { COUNTRIES_WITH_STATES_ALLOWED } from 'ee/vue_shared/leads/constants';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';

/**
 * Mixin for components that uses gl-form-fields that need country and state selection functionality.
 * Provides common data, computed properties, Apollo queries, and methods
 * for handling country/state selection with proper state management.
 */
export default {
  data() {
    return {
      countries: [],
      states: [],
    };
  },
  computed: {
    /**
     * Whether to show the country field (when countries are loaded)
     */
    showCountry() {
      return !this.$apollo.queries.countries.loading;
    },
    /**
     * Whether the selected country requires a state selection
     */
    stateRequired() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.formValues.country);
    },
    /**
     * Whether to show the state field
     * Requires: country selected, states loaded, and country requires states
     */
    showState() {
      return !this.$apollo.queries.states.loading && this.formValues.country && this.stateRequired;
    },
  },
  apollo: {
    countries: {
      query: countriesQuery,
      update(data) {
        return data.countries.map((country) => ({
          value: country.id,
          text: country.name,
        }));
      },
    },
    states: {
      query: statesQuery,
      update(data) {
        return data.states.map((state) => ({
          value: state.id,
          text: state.name,
        }));
      },
      skip() {
        return !this.formValues.country;
      },
      variables() {
        return {
          countryId: this.formValues.country,
        };
      },
    },
  },
  methods: {
    /**
     * Handle country selection
     * Clears state value if the new country doesn't require states
     * @param {string} value - Selected country ID
     * @param {Function} formFieldsInput - GlFormFields input callback
     */
    onCountrySelect(value, formFieldsInput) {
      if (!this.showState) {
        this.formValues.state = '';
      }

      // On initialization this can be undefined
      formFieldsInput?.(value);
    },
  },
};
