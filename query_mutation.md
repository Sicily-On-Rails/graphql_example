
### Query graphql 
query {
    repos{
        name
        url
    }
}

### mutazioni graphql

mutation{
    addReview(
        input: {
            repoID: 1,
            rating: 5,
            comment: "My first comment"
        }
    ){
        id
    }

}


