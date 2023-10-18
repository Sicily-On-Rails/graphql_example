module Mutations
    module Reviews
        class Add < BaseMutation
            type Types::ReviewType, null: false
            argument :repo_id, ID, required: true
            argument :rating, String, required: true
            argument :comment, String, required: true

            def resolve(repo_id:, rating: , comment:)
                Review.create!(
                    repo_id: repo_id,
                    rating: rating,
                    comment: comment
                )
            end
        end
    end
end