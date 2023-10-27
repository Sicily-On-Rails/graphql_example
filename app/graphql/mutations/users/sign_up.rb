module Mutations
    module Users
        class Signup < BaseMutation
            type Types::SignupResult, null: false

            argument :name, String, required: true
            argument :email, String, required: true
            argument :password, String, required: true
            argument :password_conformation, String, required: true

            def resolve(name: , email:, password: , password_conformation:)
                user = User.new(
                    name: name,
                    email: email,
                    password: password,
                    password_conformation
                )

                if user.save
                    Success(user)
                else
                    Failure(user)
                end

            end
        end
    end
end