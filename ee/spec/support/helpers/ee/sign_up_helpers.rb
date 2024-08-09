# frozen_string_literal: true

module EE
  module SignUpHelpers
    def expect_password_to_be_validated
      expect(page).to have_selector('[data-testid="password-common-status-icon"]')
    end
  end
end
