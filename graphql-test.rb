=begin
operation = <<~GQL
    query {
        testField
    }
    GQL
=end



=begin
#Get all repositories
query = <<~QUERY
    query {
        repos {
            name
            url
        }
    }
    QUERY
=end


=begin
#Get a single repository
query = <<~QUERY
    query{
      repo(id: 1) {
        name
        nameReversed
        url
      }
    }
    QUERY
=end



result = RepoHeroSchema.execute(query)
puts JSON.pretty_generate(result)