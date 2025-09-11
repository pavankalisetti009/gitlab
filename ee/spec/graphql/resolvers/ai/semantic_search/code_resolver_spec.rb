# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resolvers::Ai::SemanticSearch::CodeResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }

  let(:query_obj) { instance_double(Ai::ActiveContext::Queries::Code) }
  let(:result) { [{ path: "python/server.py", content: "from http.server import HTTPServer" }] }

  subject(:resolver) do
    resolve(
      described_class,
      obj: nil,
      args: { limit: limit, knn: knn_count, project: project_info, search_term: search_term },
      ctx: { current_user: current_user }
    )
  end

  shared_examples "semantic code search success" do
    it "returns required amount of questions" do
      expect(Ai::ActiveContext::Queries::Code)
        .to receive(:new)
        .with(search_term: search_term, user: current_user)
        .and_return(query_obj)

      expect(query_obj)
        .to receive(:filter)
        .with(
          project_id: project.id,
          path: expected_path,
          knn_count: knn_count,
          limit: limit
        )
        .and_return(result)

      expect(resolver.size).to eq(1)
      expect(resolver.first[:path]).to eq("python/server.py")
      expect(resolver.first[:content]).to eq("from http.server import HTTPServer")
    end
  end

  describe "#resolve" do
    context "with project id and project path" do
      let(:project_info) { { projectId: project.id, directory_path: "python/server.py" } }
      let(:search_term) { "Add raise Exception for protected type usage" }
      let(:expected_path) { "python/server.py" }
      let(:knn_count) { 64 }
      let(:limit) { 20 }

      include_examples "semantic code search success"

      context "when code_snippet_search_graphqlapi featur flag is disable" do
        before do
          stub_feature_flags(code_snippet_search_graphqlapi: false)
        end

        it "returns a GraphQL::ExecutionError" do
          err = resolver
          expect(err).to be_a(GraphQL::ExecutionError)
          expect(err.message).to eq(
            "`code_snippet_search_graphqlapi` feature flag is disabled."
          )
        end
      end
    end

    context "with project id only" do
      let(:project_info) { { projectId: project.id } }
      let(:search_term) { "Add raise Exception for protected type usage" }
      let(:expected_path) { nil }
      let(:knn_count) { 64 }
      let(:limit) { 20 }

      include_examples "semantic code search success"
    end

    context "with project id but missing search term" do
      let(:project_info) { { projectId: project.id } }
      let(:search_term) { nil }
      let(:knn_count) { 64 }
      let(:limit) { 20 }

      it "returns a GraphQL::ExecutionError" do
        err = resolver
        expect(err).to be_a(GraphQL::ExecutionError)
        expect(err.message).to eq(
          "`null` is not a valid input for `String!`, please provide a value for this argument."
        )
      end
    end
  end
end
