query {
    repo($id: id){
        reviews{
            nodes {
                user{
                    name
                }
            }
        }
    }
}