module Types
    class EventType < Types::BaseUnion
        possible_types Types::ReviewType, Types::LikeType

        def self.resolve_type(object, context)
            if object.is_a?(Review)
              Types::ReviewType
            elsif object.is_a?(Like)
              Types::LikeType
            else
              raise "Unexpected type: #{object}"
            end
          end
=begin
        def self.resolve_type(object, context)
            case object
            when Review
                Types::ReviewType
            when LikeType
                Types::LikeType
            end
        end
=end

    end
end