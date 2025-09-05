# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  include ListboxHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  describe 'New agent' do
    before do
      sign_in(user)

      visit explore_ai_catalog_path
    end

    it('navigates to New agent form, fills form and submit') do
      click_link('New agent')

      expect(page).to have_css('h1', text: 'New agent')

      select_from_listbox project.name, from: 'Select a project'
      find_by_testid('agent-form-input-name').set('New agent name')
      find_by_testid('agent-form-textarea-description').set('New agent description')
      find_by_testid('agent-form-textarea-system-prompt').set('System prompt')
      find_by_testid('agent-form-textarea-user-prompt').set('User prompt')

      click_button 'Create agent'

      agents = page.all('[data-testid="ai-catalog-item"]')
      expect(agents.length).to be(1)

      expect(page).to have_css('h2', text: 'New agent name')
    end
  end
end
