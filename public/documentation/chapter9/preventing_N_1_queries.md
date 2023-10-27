### Prevenzione delle query N+1

Uno dei probelmi più comuni riguardo a un'API GraphQL è che porta facilmente a query N+1. Ciò avviene perché il client può richiedere qualsiasi dato desideri, e il server deve risolverlo. Nel nostro caso, siamo pericolosamente vicini a permettere alla nostra applicazione di richiedere le recensioni di un repository e tutti gli utenti associati a tutte queste recensioni utilizzando una query come:

```ruby
query {
    repo(id: 1) {
        reviews {
            nodes {
                user {
                    name
                }
            }
        }
    }
}
```
Le query per questo saranno

* Una query per il repository.
* Una query per una lista paginata di recensioni.
* Una query per ogni recensione per l'utente di quella recensione.

Al momento non permettiamo ancora ai consumatori della nostra API di trovare le informazioni dell'utente da una recensione, ma avrebbe senso che la nostra applicazione supporti questa funzionalità, considerando gli sforzi compiuti nel capitolo precedente per associare gli utenti alle recensioni.

Quindi iniziamo questo capitolo aggiungendo la capacità di ottenere un utente da una recensione, dimostrando così il problema N+1. Poi, lo risolveremo.

#### Repository, recensioni e utenti

Scriviamo un test che recupera un repository, le sue recensioni e quindi gli utenti di queste recensioni. Questo test utilizzerà la query sopra menzionata e assicurerà che saremo in grado di riprodurre il problema N+1.
`spec/requests/graphql/queries/repo_review_users_spec.rb`
```ruby
require 'rails_helper'

RSpec.describe "Graphql, repo query, with reviews" do
    let!(:repo) { Repo.create!(name: "Repo Hero", url:  "https://github.com/repohero/repohero") }
    before do
        15.times do |i|
            user = User.create!(
            name: "Test User #{i}",
            email: "test#{i}@example.com",
            password: "SecurePassword1"
            )
            repo.reviews.create!(rating: 5, comment: "Review #{i}", user: user)
        end
    end


    it "retrieves all the users for reviews on a repo" do
    query = <<~QUERY
        query ($id: ID!) {
            repo(id: $id) {
                ...on Repo {
                    name
                    reviews {
                        nodes {
                            user {
                                name
                            }
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
    
    users = response.parsed_body.dig("data", "repo", "reviews", "nodes").map { |node| node["user"] }
        expect(users).to be_present
    end
end

```

In questo test, ci aspettiamo di vedere 10 recensioni, poiché è il numero predefinito di recensioni che la nostra API restituirà. E con queste 10 recensioni, ci aspettiamo che tutte facciano riferimento allo stesso utente.

Quando eseguiamo questo test con `bundle exec rspec spec/requests/graphql/queries/repo_review_users_spec.rb`, vedremo che non c'è un campo chiamato `user` nel tipo Review

```sh
Failure/Error: expect(response.parsed_body).not_to have_errors
    Expected there to be no errors, but there were:
    [
        {
         "message": "Field 'user' doesn't exist on type 'Review'",
   ....
```

Quindi aggiungiamo ora quel campo al nostro tipo Review:

`app/graphql/types/review_type.rb`
```ruby
module Types
    class ReviewType < Types::BaseObject
        field :id, ID, null: false
        field :rating, ReviewRating, null: false
        field :comment, String, null: false
        field :user, UserType, null: false
    end
end
```
Da notare che stiamo utilizzando un nuovo tipo per l'utente, chiamato `UserType`. Stiamo facendo una distinzione qui nella nostra applicazione tra un utente autenticato e un utente normale. Un tipo di utente autenticato contiene il token di autenticazione JWT e qualsiasi altra informazione che un utente potrebbe conoscere su se stesso. Mentre il tipo UserType conterrà solo informazioni che gli utenti potrebbero conoscere gli uni sugli altri.

Attualmente, la classe UserType è indefinita, quindi dovremo crearla anche:
`app/graphql/types/user_type.rb`
```ruby
module Types
    class UserType < BaseObject
        field :name, String, null: false
    end
end
```

La quantità massima di informazioni che gli utenti possono conoscere gli uni degli altri riguarda i loro nomi. Non sarà possibile accedere a indirizzi email o token di autenticazione con questo nuovo tipo.

Con il campo aggiunto al `ReviewType` e con la classe `UserType` definita, quando eseguiamo il nostro test ora vediamo che sta passando:

```sh
1 example, 0 failures
```

Questa è una buona notizia, ma non eravamo qui solo per aggiungere utenti alle recensioni. Volevamo anche dimostrare una query N+1. Quando apriamo il file log/test.log, vediamo che sono state eseguite queste query per il test:

```sh
Repo Load (0.1ms) SELECT "repos".* FROM "repos" WHERE "repos"."id" = ?
LIMIT ? [["id", 1], ["LIMIT", 1]]
Review Load (0.0ms) SELECT "reviews".* FROM "reviews" WHERE
"reviews"."repo_id" = ? LIMIT ? OFFSET ? [["repo_id", 1], ["LIMIT", 10],
["OFFSET", 0]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 2], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 3], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 4], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 5], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 6], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 7], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 8], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 9], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 10], ["LIMIT", 1]]
User Load (0.0ms) SELECT "users".* FROM "users" WHERE "users"."id" = ?
LIMIT ? [["id", 11], ["LIMIT", 1]]
```

Questo è il problema N+1. Abbiamo 1 query per le recensioni di un repository e quindi N query per ciascuno degli utenti di tali recensioni. Una query per utente sarà sempre più lenta di una query per tutte le recensioni.


#### Dataloader

Per risolvere il problema del caricamento degli utenti per le recensioni uno per uno, possiamo utilizzare una funzionalità delle gemme GraphQL chiamata Dataloader. Un dataloader raccoglie gli ID degli oggetti che devono essere caricati e quindi li carica tutti in una volta. Ciò significa che possiamo caricare tutti gli utenti per tutte le recensioni in una sola query, anziché una query per ogni utente.

Per utilizzare questa funzionalità all'interno della nostra applicazione, dovremo modificare il modo in cui ReviewType recupera i suoi utenti

`app/graphql/types/review_type.rb`

```ruby
field :user, UserType, null: false
def user
    dataloader.with(Sources::ActiveRecord, User).load(object.user_id)
end
```
"Il metodo dataloader proviene da un modulo inserito nello schema RepoHeroSchema:
`app/graphql/repo_hero_schema.rb`

```ruby
use GraphQL::Dataloader
```
Quando utilizziamo quel metodo in combinazione con il metodo 'with', stiamo definendo un dataloader per un campo specifico. Il metodo 'with' richiede una sorgente, che sarà una classe che corrisponderà all'API delle sorgenti. Una sorgente in GraphQL riceve una lista di ID e caricherà in modo pigro questi oggetti, proprio mentre vengono risolti.

In questo caso, utilizzeremo una sorgente chiamata Sources::ActiveRecord. Questa sorgente particolare riceve un modello come argomento e quindi caricherà le istanze dal database in base alle chiavi che le viene detto di caricare.

Se avessimo un altro modo per recuperare le istanze, ad esempio se fossero memorizzate in un database diverso come Redis, potremmo definire una sorgente unica per recuperare quelle istanze.

Per definire la nostra sorgente per ActiveRecord, dovremo creare una nuova classe:
`app/graphql/sources/active_record.rb`

```ruby
class Sources::ActiveRecordObject < GraphQL::Dataloader::Source
    def initialize(model_class)
        @model_class = model_class
    end

    def fetch(ids)
    records = @model_class.where(id: ids)
        # return a list with `nil` for any ID that wasn't found
        ids.map { |id| records.find { |r| r.id == id.to_i } }
    end
end
```

La gemma GraphQL stessa non include questa classe perché non tutte le applicazioni che utilizzano questa gemma utilizzerebbero Active Record. Sicuramente, si potrebbe sostenere che la sovrapposizione è piuttosto considerevole, ma questa è stata una decisione di progettazione presa dagli autori di questa gemma.

Ora, ReviewType utilizzerà questa sorgente per caricare gli utenti pertinenti:

`app/graphql/types/review_type.rb`
```ruby
field :user, UserType, null: false
def user
    dataloader.with(Sources::ActiveRecord, User).load(object.user_id)
end
```

Quando eseguiamo di nuovo il nostro test e guardiamo il file `log/test.log`, vedremo che il numero di query è stato ridotto a soli tre. La query finale, quella per gli utenti, è ora questa:

```sh
User Load (0.1ms) SELECT "users".* FROM "users" WHERE "users"."id" IN
(...)
```

Questo ha eliminato il problema N+1 che si verificava quando caricavamo gli utenti per le recensioni. Sebbene ciò non eliminerà automaticamente tutte le possibili query N+1 all'interno della nostra applicazione, ora almeno abbiamo uno strumento che possiamo utilizzare per eliminarle quando le incontriamo.

Per ulteriori informazioni sui Dataloaders, raccomando vivamente di leggere la documentazione fornita dalla gemma GraphQL."