module Types 
    class RepoType < Types::BaseObject
        field :id, ID, Integer, null: false
        field :name, String, null: false
        field :url, String, null: false
        field :name_reversed, String, null: false
        field :categories, [Types::CategoryType], null: false

        def name_reversed
            object.name.reverse
        end

    end

    
end