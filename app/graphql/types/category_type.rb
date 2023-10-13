module Types
    class CategoryType < Types::BaseObject
        field :name, String, null: false
        field :repos, [Types::RepoType], null: false
    end
end