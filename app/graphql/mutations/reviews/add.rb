module Mutations
    module Reviews
        class Add < BaseMutation
            include Dry::Monads[:result]
            type Types::AddReviewResult, null: false
            graphql_name "AddReview"
            type Types::ReviewType, null: false
            argument :repo_id, ID, required: true
            argument :rating, Types::ReviewRating, required: true
            argument :comment, String, required: true

            
            def resolve(repo_id:, rating: , comment:)
                review = Review.create!(
                    repo_id: repo_id,
                    rating: rating,
                    comment: comment,
                )
=begin
                if review.save
                    Success(review)
                else
                    Failure(review)
                end
=end
            end


        end
    end
end