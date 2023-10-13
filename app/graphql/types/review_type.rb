module Types
    class ReviewType < Types::BaseObject
        field :id, ID, Integer, null: false
        field :rating, Integer, null: false
        field :comment, String, null: false
    end
end