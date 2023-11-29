## Paginazione

Repo Hero sta prendendo forma. Abbiamo repository e categorie nella nostra applicazione, ma la caratteristica principale che manca a Repo Hero sono le recensioni. 
Gli utenti dovrebbero poter lasciare una recensione per un repository, assegnandogli un punteggio da 1 a 5 stelle e lasciando un breve commento. Dato che Repo Hero sarà estremamente popolare, dobbiamo considerare il fatto che per un singolo repository potrebbero esserci centinaia, anzi, migliaia di recensioni per quel repository.
Non possiamo semplicemente visualizzare tutte le recensioni di un repository in una sola pagina. Invece, quello che faremo è mostrare solo un piccolo sottoinsieme delle recensioni per volta, permettendo all'utente di paginare attraverso queste recensioni per vederne di più.


#### reazione del modello "review"

Prima di poter paginare attraverso le recensioni, dovremo creare un modello per rappresentarle. Possiamo farlo eseguendo il generatore di modelli:

```sh
rails g model review repo:references rating:integer comment:text
```

Successivamente, dovremo eseguire la migrazione che è stata creata:

```sh
rails db:migrate
```

Successivamente, dovremo aggiungere l'associazione per le recensioni al modello Repo in modo da poter trovare le recensioni per un determinato repository:

`app/models/repo.rb`

```ruby
class Repo < ApplicationRecord
    has_many :categorized_repos
    has_many :categories, through: :categorized_repos
    has_many :reviews
end

```

Con questo modello ora in atto, possiamo iniziare a vedere come visualizzare un elenco di recensioni per un repository utilizzando GraphQL.

#### Utilizzo del tipo di connessione ("connection type") per mostrare le recensioni

Ora aggiungeremo un campo per le recensioni nella nostra API GraphQL. Una differenza significativa su questo campo è che sarà un campo paginato, il che significa che utilizzeremo un tipo diverso durante la definizione di questo campo. Il tipo che useremo si chiama "connection". Una connessione è un tipo utilizzato per rappresentare un elenco di elementi che possono essere paginati.


Innanzitutto, avremo bisogno di un `ReviewType` per rappresentare le nostre recensioni. Dovrebbe essere possibile restituire una valutazione e un commento per ogni recensione. Creiamo questa classe ora.

`app/graphql/types/review_type.rb`

```ruby
    module Types
        class ReviewType < Types::BaseObject
            field :rating, ReviewRating, null: false
            field :comment, String, null: false
        end
    end
```

Successivamente, definiremo il campo di connessione nella nostra classe RepoType in questo modo:

`app/graphql/types/repo_type.rb`

```ruby

module Types 
    class RepoType < Types::BaseObject
        field :id, ID, Integer, null: false
        field :name, String, null: false
        field :url, String, null: false
        field :name_reversed, String, null: false
        field :categories, [Types::CategoryType], null: false
        field :reviews, ReviewType.connection_type, null: false, default_page_size: 10
      
        def name_reversed
            object.name.reverse
        end

    end
    
end
```

La chiamata al metodo `ReviewType.connection_type` è ciò che dice a GraphQL che questo campo è un campo paginato. L'opzione `default_page_size` è ciò che dice a GraphQL quanti elementi restituire per impostazione predefinita quando viene interrogato questo campo. 10 recensioni alla volta.
Una connessione è un oggetto GraphQL che rappresenta il collegamento tra due oggetti, in questo caso un repository e una recensione. Un tipo di connessione ha tre sottocampi distinti:

- **nodes**: L'elenco degli elementi restituiti.
- **edges**: Eventuali metadati sulla relazione tra i repository e le recensioni. (O utenti e le loro iscrizioni, come nell'esempio precedente.)
- **pageInfo**: Informazioni sulla pagina corrente degli elementi, compresi dettagli su se c'è una pagina aggiuntiva di elementi dopo quella corrente.

Per questo nuovo campo delle recensioni, ci concentreremo solo su nodes e il campo pageInfo. Ecco come scriveremmo una query GraphQL per ottenere informazioni su un repository e le sue recensioni, e anche il campo pageInfo:

```ruby
query repoReviews($id: ID!) {
        repo(id: $id) {
            name
            reviews {
                nodes {
                    rating
                    comment
                }
            pageInfo {
                hasNextPage
                endCursor
            }
        }
    }
}   
```
Se avessimo qualche recensione per i repository configurata nella nostra applicazione, i dati che otterremmo sarebbero questi:

```ruby
{
    "data": {
        "repo": {
            "name": "Repo Hero",
            "reviews": {
                "nodes": [
                    {
                        "rating": 5,
                        "comment": "Review 1"
                    },
                    ...
                    {
                        "rating": 5,
                        "comment": "Review 10"
                    }
                    ],
                    "pageInfo": {
                        "hasNextPage": true,
                        "endCursor": "MTA"
                    }
            }
        }
    }
}
```

Il campo pageInfo è ciò che ci dice se ci sono altre recensioni da recuperare, e in tal caso, qual è il cursore per la pagina successiva delle recensioni. Il cursore qui è una stringa codificata in Base64 dell'ID del record - 10 in questo caso.

Per recuperare la pagina successiva delle recensioni, utilizziamo l'argomento `after` sul campo delle recensioni:

```ruby
query ($id: ID!) {
        repo(id: $id) {
            name
            reviews(after: "MTA") {
                nodes {
                    rating
                    comment
                }
            pageInfo {
                hasNextPage
                endCursor
            }
        }
    }
}


```

Questo restituirà quindi tutte le recensioni dopo la decima recensione:

```ruby
{
    "data": {
        "repo": {
            "name": "Repo Hero",
                "reviews": {
                "nodes": [
                    {
                    "rating": 5,
                    "comment": "Review 11"
                    },
                    ...
                    {
                    "rating": 5,
                    "comment": "Review 20"
                    }
                ],
                "pageInfo": {
                    "hasNextPage": true,
                    "endCursor": "MjA"
                }
            }
        }
    }
}
```
Ora che abbiamo visto come funziona questa paginazione, dovremmo aggiungere un test per assicurarci che funzioni ora e anche in futuro.

Scrivimao il seguente test:

`spec/requests/graphql/queries/repo_reviews_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Graphql, repo query, with reviews" do
  
  let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }
  before do
    15.times do |i|
      repo.reviews.create!(rating: 5, comment: "Review #{i}")
    end
  end

  it "retrieves a single repo, with two pages of reviews" do
    query = <<~QUERY
    query ($id: ID!, $after: String) {
      repo(id: $id) {
        ...on Repo {
          name
          reviews(after: $after) {
            nodes {
              rating
              comment
            }
            pageInfo {
              endCursor
            }
          }
        }
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: { id: repo.id } }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to match(
      "repo" => a_hash_including(
        "name" => repo.name,
      )
    )

    expect(response.parsed_body.dig("data", "repo", "reviews", "nodes").count).to eq(10)
    end_cursor = response.parsed_body.dig("data", "repo", "reviews", "pageInfo", "endCursor")

    post "/graphql", params: { query: query, variables: { id: repo.id, after: end_cursor } }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to match(
      "repo" => a_hash_including(
        "name" => repo.name,
      )
    )

    expect(response.parsed_body.dig("data", "repo", "reviews", "nodes").count).to eq(5)
  end
end

```

Questo test inizia creando 15 recensioni per un repository. Dieci di queste recensioni appariranno sulla prima pagina delle recensioni e cinque appariranno sulla pagina successiva. 

La query utilizzata in questo test utilizza una variabile chiamata after per navigare attraverso l'elenco delle recensioni. Per la prima pagina dei risultati, non specifichiamo una variabile after.

Per la seconda pagina dei risultati, utilizziamo il valore di endCursor dalla prima pagina dei risultati per recuperare quella pagina. Sia per la prima che per la seconda pagina dei risultati facciamo alcune asserzioni che la query sta recuperando il numero corretto di recensioni.

Ora che abbiamo un test, possiamo eseguirlo e vedere se il nostro campo delle recensioni funziona come previsto:

```sh
bundle exec rspec spec/requests/graphql/queries/repo_reviews_spec.rb
```

Questo test passerà, poiché abbiamo il campo delle recensioni all'interno del nostro RepoType.