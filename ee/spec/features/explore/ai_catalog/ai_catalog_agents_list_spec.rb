# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }

  before do
    enable_ai_catalog
  end

  describe 'Agents' do
    before do
      visit explore_ai_catalog_path
    end

    it('displays tabs') do
      page.within('.gl-tabs') do
        expect(page).to have_link('Agents')
        expect(page).to have_link('Flows')
      end
    end

    it('does not display new agent button as link') do
      expect(page).not_to have_link('New agent')
    end

    it 'displays an empty list of agents' do
      expect(page).to have_content('Get started with the AI Catalog')
      expect(page).to have_content('Build agents and flows to automate tasks and solve complex problems.')

      agents = page.all('[data-testid="ai-catalog-item"]')
      expect(agents.length).to be(0)
    end

    context 'when there are existing agents' do
      let_it_be(:agent1) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 1', public: true) }
      let_it_be(:agent2) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 2', public: true) }
      let_it_be(:agent3) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 3', public: true) }
      let_it_be(:agent4) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 4') }
      let_it_be(:agent5) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 5') }
      let_it_be(:agent6) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 6') }

      it 'displays public agents' do
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(3)
      end

      context 'when user has permissions' do
        before_all do
          project.add_maintainer(user)
        end

        before do
          sign_in(user)
          visit explore_ai_catalog_path
        end

        it 'displays public and private agents' do
          agents = page.all('[data-testid="ai-catalog-item"]')
          expect(agents.length).to be(6)
        end
      end
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
        visit explore_ai_catalog_path
      end

      it('displays new agent button as link') do
        expect(page).to have_link('New agent')
      end
    end
  end
end
