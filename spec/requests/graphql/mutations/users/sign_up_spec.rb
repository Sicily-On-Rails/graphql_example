mutation signup(
    $name: String!,
    $email: Strign!,
    $password: String!,
    $password_conformation: String!

){

signup(
    input: {
        name: $name,
        email: $email,
        password: $password,
        password_conformation: $password_conformation
    }
    ){
        email
        token
    }
}

require 'rails_helper'

RSpec.describe "GraphQL, signUp mutation" , type: :request do

    let(:query) do
        <<~QUERY
        mutation signup($name: String!, $email: Strign!, $password: String!,$password_conformation: String!){
            signup(
            input: {
                name: $name,
                email: $email,
                password: $password,
                password_conformation: $password_conformation
            }
            ){
                ...on User{
                    email
                    token
                }
                ... on ValidationError{
                    errors {
                        fullMessages
                        attributeErrors{
                            attribute
                            errore
                        }
                    }
                }
            }
        }
        QUERY
    end

    it  "sign up a new user successfully" do
        post "/graphql", params: {
            query: query,
            variables: {
                name: "name"
                email: "test@example.com",
                password: "Password123",
                password_conformation: "Password123",
            }
        }

        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to match(
            "signup" => {
                "email": "test@example.com",
            }
        )
        expect(response.parsed_body["data"]["signup"]["token"]).to be_present
    end

    
    it "cannot sign up with a missing email" do
        post "/graphql", params: {
            query: query,
            variables: {
                name: "name"
                email: "",
                password: "Password123",
                password_conformation: "Password123",
            }
        }

        expect(response.parsed_body).not_to have_errors
        signup = response.parsed_body["data"]["signup"]
        expect(signup).to eq(
            "errors" => {
                "fullMessages" => ["Email can't blank"],
                "attributesErrors" => [
                    {
                        "attribute" => "email",
                        "errors" => ["can't blank"]
                    }
                ]
            }
        )

        
    end



end