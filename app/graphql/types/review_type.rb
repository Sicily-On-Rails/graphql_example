    module Types
        class ReviewType < Types::BaseObject
            field :id, ID, null: false
            #field :rating, ReviewRating, null: false
            field :rating, Integer, null: false
            field :comment, String, null: false


            field :user, UserType, null: false

            def user
                dataloader.with(Source::ActiveRecord, User).load(object.user_id)     
            end

        end
    end