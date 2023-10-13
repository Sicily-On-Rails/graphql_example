require 'rails_helper'

RSpec.describe "Graphql, category query" do
  let!(:category) { Category.create!(name: "Ruby") }

  it "retrieves a single category" do
    query = <<~QUERY
    query($id: ID!) {
      category(id: $id) {
        name
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: {id: category.id} }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "category" => 
        {
          "name" => category.name,
        }
    )
  end
end