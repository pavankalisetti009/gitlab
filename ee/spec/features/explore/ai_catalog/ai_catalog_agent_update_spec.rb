# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:agent1) do
    create(:ai_catalog_agent, project_id: project.id, name: 'Agent 1', description: 'Agent Description', public: true)
  end

  describe 'Update existing agent' do
    before do
      sign_in(user)

      visit explore_ai_catalog_path
    end

    it('navigates to Edit agent form from more actions menu, updates values and submit') do
      agents = page.all('[data-testid="ai-catalog-item"]')
      expect(agents.length).to be(1)
      expect(page).to have_content('Agent Description')

      click_button('More actions')
      click_link('Edit')

      fill_edit_form_and_submit
    end

    it('navigates to Edit agent form from drawer, updates values and submit') do
      agents = page.all('[data-testid="ai-catalog-item"]')
      expect(agents.length).to be(1)

      click_link(agent1.name)

      page.within('aside') do
        expect(page).to have_content('Agent Description')
        expect(page).to have_content('Talk like a pirate!')
      end

      click_link('Edit')

      fill_edit_form_and_submit
    end
  end

  def fill_edit_form_and_submit
    expect(page).to have_css('h1', text: "Edit agent: #{agent1.name}")

    find_by_testid('agent-form-input-name').set('Updated agent name')
    find_by_testid('agent-form-textarea-description').set('Updated agent description')
    find_by_testid('agent-form-textarea-system-prompt').set('Updated System prompt')
    find_by_testid('agent-form-textarea-user-prompt').set('Updated User prompt')

    click_button 'Save changes'

    agents = page.all('[data-testid="ai-catalog-item"]')
    expect(agents.length).to be(1)

    expect(page).to have_css('h2', text: 'Updated agent name')

    expect(page).not_to have_content('Agent Description')
    expect(page).to have_content('Updated agent description')

    expect(page).not_to have_content('Talk like a pirate!')
    expect(page).to have_content('Updated System prompt')
  end
end
