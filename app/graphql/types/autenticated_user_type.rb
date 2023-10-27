module Types
    class AuthenticatedUserType < BaseObject
        field :email, String, null: false
        field :token, String, null: false

        def token
            Jot.encode(email: object.email)
        end
    end
end