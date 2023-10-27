module Types
    possible_types Types::AuthenticatedUserType, Types::ValidationErrorType

    def self.resolve_type(object, _conteext)
        if object.success?
            [Types::AuthenticatedUserType, object.success]
        else
            [Types::ValidationErrorType], object.failure]
        end
    end
    
end