<script>
import { debounce, entries } from 'lodash';
import { GlIcon } from '@gitlab/ui';
import * as UsersApi from 'ee/api/users_api';
import { __ } from '~/locale';
import { createAlert } from '~/alert';
import { THOUSAND } from '~/lib/utils/constants';

import {
  COMMON,
  INVALID_FORM_CLASS,
  INVALID_INPUT_CLASS,
  PASSWORD_REQUIREMENTS_ID,
  PASSWORD_RULE_MAP,
  RED_TEXT_CLASS,
  GREEN_TEXT_CLASS,
  HIDDEN_ELEMENT_CLASS,
  I18N,
} from '../constants';

export default {
  components: {
    GlIcon,
  },
  props: {
    allowNoPassword: {
      type: Boolean,
      required: true,
    },
    passwordInputElement: {
      type: Element,
      required: true,
    },
    ruleTypes: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      password: '',
      submitted: false,
      ruleList: this.ruleTypes.map((type) => ({ type, valid: false, ...PASSWORD_RULE_MAP[type] })),
    };
  },
  computed: {
    anyInvalidRule() {
      return this.ruleList.some((rule) => !rule.valid) && !this.isEmptyPasswordLegal;
    },
    isEmptyPasswordLegal() {
      return this.password.trim() === '' && this.allowNoPassword;
    },
    boxClasses() {
      return {
        // make class permanent with display_password_requirements ff removal
        'gl-text-secondary': this.ruleTypes.includes(COMMON),
      };
    },
  },
  watch: {
    password() {
      this.ruleList.forEach((rule) => this.checkValidity(rule));
    },
    anyInvalidRule() {
      if (this.anyInvalidRule && this.submitted) {
        this.passwordInputElement.classList.add(INVALID_INPUT_CLASS);
      } else {
        this.passwordInputElement.classList.remove(INVALID_INPUT_CLASS);
      }
    },
  },
  mounted() {
    const formElement = this.passwordInputElement.form;

    this.passwordInputElement.setAttribute('aria-describedby', PASSWORD_REQUIREMENTS_ID);
    this.passwordInputElement.addEventListener('input', () => {
      this.password = this.passwordInputElement.value;
    });

    formElement.querySelector('[type="submit"]').addEventListener('click', () => {
      this.submitted = true;
      if (this.anyInvalidRule) {
        this.passwordInputElement.focus();
        this.passwordInputElement.classList.add(INVALID_INPUT_CLASS);
        formElement.classList.add(INVALID_FORM_CLASS);
      }
    });

    formElement.addEventListener('submit', (e) => {
      if (this.anyInvalidRule) {
        e.preventDefault();
        e.stopPropagation();
      }
    });
  },
  methods: {
    validatePasswordComplexity(password) {
      UsersApi.validatePasswordComplexity(password)
        .then(({ data }) =>
          entries(data).forEach(([key, value]) => this.setRuleValidity(key, !value)),
        )
        .catch(() =>
          createAlert({
            message: __('An error occurred while validating password'),
          }),
        );
    },
    debouncedComplexityValidation: debounce(function complexityValidation(password) {
      this.validatePasswordComplexity(password);
    }, THOUSAND),
    checkValidity(rule) {
      if (rule.type === COMMON) {
        this.checkComplexity(rule);
      } else {
        this.setRuleValidity(rule.type, rule.reg.test(this.password));
      }
    },
    checkComplexity(rule) {
      if (this.password) {
        this.debouncedComplexityValidation(this.password);
      } else {
        this.setRuleValidity(rule.type, false);
      }
    },
    setRuleValidity(type, valid) {
      const rule = this.findRule(type);

      if (rule) {
        rule.valid = valid;
      }
    },
    findRule(type) {
      return this.ruleList.find((rule) => rule.type === type);
    },
    getAriaLabel(rule) {
      if (rule.valid) {
        return I18N.PASSWORD_SATISFIED;
      }
      if (this.submitted) {
        return I18N.PASSWORD_NOT_SATISFIED;
      }
      return I18N.PASSWORD_TO_BE_SATISFIED;
    },
    calculateTextClass(rule) {
      return {
        [this.$options.RED_TEXT_CLASS]: this.submitted && !rule.valid,
        [this.$options.GREEN_TEXT_CLASS]: rule.valid,
      };
    },
  },
  RED_TEXT_CLASS,
  GREEN_TEXT_CLASS,
  HIDDEN_ELEMENT_CLASS,
};
</script>

<template>
  <div v-show="!isEmptyPasswordLegal" data-testid="password-requirement-list" :class="boxClasses">
    <div
      v-for="(rule, index) in ruleList"
      :key="rule.text"
      class="gl-flex gl-items-center gl-leading-28"
      aria-live="polite"
    >
      <span
        :class="{ [$options.HIDDEN_ELEMENT_CLASS]: !rule.valid }"
        :data-testid="`password-${ruleTypes[index]}-status-icon`"
        class="password-status-icon password-status-icon-success gl-mr-2 gl-flex gl-items-center"
        :aria-label="getAriaLabel(rule)"
      >
        <gl-icon name="check" :size="16" />
      </span>
      <span data-testid="password-rule-text" :class="calculateTextClass(rule)">
        {{ rule.text }}
      </span>
    </div>
  </div>
</template>
