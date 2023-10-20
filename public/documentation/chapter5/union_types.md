#### Union Types

I tipi di unione in GraphQL sono ciò che utilizziamo quando un campo può risolversi in due o più valori potenziali.
Nel capitolo precedente abbiamo aggiunto delle recensioni ai repository. In questo capitolo, aggiungeremo un nuovo tipo di attività che un utente può eseguire su un repository: un "Like". 

Un "Like" è un semplice pollice in su che un utente può dare a un repository. Non ha una valutazione o un commento: è un rapido segno di approvazione.

Successivamente, restituiremo recensioni e "Like" nella stessa lista di attività. In tale elenco di attività, un'attività può essere una recensione o un "Like". Quando si effettua una query per questa lista di attività, la tratteremo come una raccolta paginata di elementi.

```ruby
query ($id: ID!) {
    repo(id: $id) {
        name
        url
        activities {
            nodes {
                __typename
                ... on Review {
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

```

Il campo "__typename" che stiamo selezionando qui restituirà il tipo per ciascuna singola attività. Sarà o `Review` o `Like`. Lo useremo successivamente nei nostri test per verificare quale tipo viene restituito dalla nostra query.
La sintassi `… on` in GraphQL indica alla nostra API quali campi vogliamo che siano risolti per ciascun tipo individuale dell'unione. Se un record di attività restituisce un `Like`, vogliamo sapere quando è stato creato. Se restituisce una `Review`, vogliamo conoscere la valutazione e il commento.
Per implementare questo, creeremo un modello per rappresentare i `Like` per un repository, nonché un modello per rappresentare il flusso di attività per un repository. Successivamente scriveremo un test per questo tipo di unione e lo implementeremo nell'API GraphQL.

#### Impostiamo i modelli
Iniziamo creando un modello per rappresentare i `Like` per i repository. In alcune applicazioni, potremmo voler collegare questi modelli agli utenti. Tuttavia, al momento la nostra applicazione non dispone di una rappresentazione degli utenti, quindi il nostro modello conterrà solo un timestamp di quando è stato creato il "Like" e un collegamento al repository che è stato apprezzato.
Creiamo ora questo modello:

```sh
rails g model like repo:references
```

Creeremo anche un modello per rappresentare le diverse attività per un repository:

```sh
rails g model activity repo:references event:references{polymorphic}
```

Questo modello avrà un'associazione polimorfica all'evento che ha scatenato l'attività. Utilizzeremo questa associazione polimorfica per collegarci sia a una recensione che a un "Like".


Quando avremo righe nella tabella delle attività, avranno questa forma:


| id  | repo_id  |  event_type |   event_id|   |
|---|---|---|---|---|
|  1 |  2 |  Like |  3 |   |
| 2  |  3 |  Review |   4|   |
|   |   |   |   |   |


Utilizzando una relazione polimorfica, possiamo utilizzare la tabella delle attività per rappresentare i collegamenti tra un repository e i "Like", nonché un repository e le sue recensioni.
Successivamente, eseguiremo la migrazione per il modello al fine di configurare le tabelle che abbiamo appena creato:

```sh
rails db:migrate
```

Aggiungeremo anche le associazioni per entrambi questi modelli al nostro modello "Repo". Ecco un esempio di come potrebbe apparire nel codice:

```ruby
# app/models/repo.rb
class Repo < ApplicationRecord
  has_many :categorized_repos
  has_many :categories, through: :categorized_repos
  has_many :reviews
  has_many :likes
  has_many :activities
end
```

Nel codice sopra, stiamo dichiarando che un repository può avere molte recensioni, molti "Like" e molte attività associate a esso. Queste associazioni ci permetteranno di accedere facilmente a queste relazioni quando lavoriamo con un oggetto "Repo" nel nostro codice Ruby on Rails.

Adesso scriviamo un test per il nostro tipo di unione. Inizieremo scrivendo un test che garantisce che possiamo effettuare una query per le attività di un repository e ottenere sia i "Like" che le recensioni:

`spec/requests/graphql/queries/repo_activities_spec.rb`
```ruby
require 'rails_helper'
    RSpec.describe "Graphql, repo query, with activity" do

    let!(:repo) { Repo.create!(name: "Repo Hero", url:
    "https://github.com/repohero/repohero") }

    before do
        review = repo.reviews.create!(rating: 5, comment: "Review #{i}")
        like = repo.likes.create!
        repo.activities.create(event: review)
        repo.activities.create(event: like)
    end

    it "retrieves a single repo with a list of activities" do
        query = <<~QUERY
            query ($id: ID!) {
                repo(id: $id) {
                    name
                    activities {
                        nodes {
                        __typename
                        ... on Review {
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
        QUERY

        post "/graphql", params: { query: query, variables: { id: repo.id } }
        
        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to match(
            "repo" => a_hash_including(
            "name" => repo.name,
            )
        )
        activities = response.parsed_body.dig("data", "repo", "activities","nodes")
        
        expect(activities.count).to eq(2)
    end
end

```

In questo test, stiamo affermando che quando facciamo una query per un campo "activities" su un repository, otteniamo le recensioni e i "Like" creati all'inizio di questo test. 

Quando eseguiamo questo test con:

"bundle exec rspec spec/requests/graphql/queries/repo_activities_spec.rb", 

ci verrà segnalato che il campo "activities" manca:

`app/graphql/types/repo_type.rb`

```ruby
module Types
    class RepoType < Types::BaseObject
    field :activities, ActivityType.connection_type, null: false
    #....
```

Per trovare le attività pertinenti per un repository, questo campo GraphQL utilizzerà il metodo Repo#activities definito dalla relazione has_many nel modello "Repo". Successivamente, dovremo aggiungere la classe "ActivityType" a cui fa riferimento questo nuovo campo:

Successivamente, sarà necessario aggiungere la classe "ActivityType" a cui fa riferimento il nuovo campo.

```ruby

```

`app/graphql/types/activity_type.rb`

```ruby
module Types
    class ActivityType < Types::BaseObject
        field :event, EventType, null: false
    end
end
```
Questa classe "ActivityType" avrà un campo chiamato "event" che restituirà un "EventType". Questo "EventType" sarà il nostro tipo di unione. Definiamo ora questo nuovo tipo:

`app/graphql/types/event_type.rb`

```ruby
module Types
    class EventType < Types::BaseUnion
        possible_types ReviewType, LikeType
        
        def self.resolve_type(object, context)
            case object 
            when Review
                ReviewType
            when Like
                LikeType
            end
        end
    end
end
```


Nota che stiamo utilizzando la classe padre "BaseUnion" invece della nostra solita classe padre "BaseObject".
La classe "BaseUnion" include il metodo "possible_types", che possiamo utilizzare per definire i tipi che possono essere restituiti da questa unione. In questo caso, stiamo indicando che l'ActivityType può restituire sia un ReviewType che un LikeType. Ancora una volta, in un'unione possono esserci più di due tipi, ma in questo esempio ne avremo solo due. L'unica restrizione su quanti tipi possono essere restituiti in un'unione è la tua immaginazione.
Quando un oggetto EventType viene risolto nel nostro schema GraphQL, il metodo "resolve_type" viene chiamato per determinare quale classe utilizzare per rappresentare quel tipo. Questo metodo riceve l'argomento oggetto, che sarà un'istanza del modello Review o del modello Like. Se è un'istanza di Review, allora useremo ReviewType per risolvere il campo. Se è un Like, useremo LikeType.
Dei due tipi possibili definiti nella nostra unione, solo ReviewType ha una classe definita per esso. Al momento non abbiamo ancora una classe definita per LikeType. Creiamo ora questa classe:

`app/graphql/types/like_type.rb`

```ruby
module Types
    class LikeType < Types::BaseObject
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
end
```
Questo tipo verrà utilizzato per rappresentare i "Like" restituiti dalla risoluzione degli eventi delle attività nella nostra API. Attualmente, l'unico dato che desideriamo restituire da questo campo è un timestamp, ma in futuro potremmo voler restituire anche informazioni sull'utente associato al "Like" per visualizzare tali informazioni.
Con il nuovo campo e i tre nuovi tipi (ActivityType, EventType e LikeType) configurati nel nostro sistema, possiamo eseguire nuovamente il nostro test e vedere che ora sta passando.

Ottimo! Per risolvere le attività per un repository, abbiamo definito un nuovo campo chiamato "activities" nella classe RepoType. Successivamente, per risolvere l'evento rilevante per un'attività, abbiamo definito la classe ActivityType per restituire una classe di unione EventType. Questa classe viene quindi utilizzata per risolvere gli eventi in oggetti che verranno risolti utilizzando le classi LikeType o ReviewType.

I tipi di unione in GraphQL sono molto utili quando abbiamo più di un singolo tipo di oggetto che desideriamo restituire per lo stesso campo. Ma questa non è l'unica loro utilità. 