# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :add_review, mutation: Mutations::Reviews::Add
    field :update_review, mutation: Mutations::Reviews::Update
    field :delete_review, mutation: Mutations::Reviews::Delete

    field :signup, mutation: Mutations::Users::SignUp
    field :login, mutation: Mutations::Users::Login
    
    # TODO: remove me
    field :test_field, String, null: false,
      description: "An example field added by the generator"
    def test_field
      "Hello World"
    end
  end
end
