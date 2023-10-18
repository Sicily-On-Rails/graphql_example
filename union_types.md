```ruby
query($id: ID!){
    repo(id: $id){
        name
        url
        activities{
            node{
                __typename{
                    ... on Review{
                        rating
                        comment
                    }
                    ... on Like {
                        createdAt
                    }
                }

            }

        }
    }

}


```