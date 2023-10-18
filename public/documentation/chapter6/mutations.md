#### Mutazioni
 In questo capitolo, inizieremo a scrivere dati all'interno della nostra applicazione attraverso la stessa API. 
 
 GraphQL traccia una chiara distinzione tra le operazioni di lettura dei dati e le operazioni di scrittura dei dati. Le operazioni di lettura sono chiamate query e le operazioni di scrittura sono chiamate mutazioni. E sono proprio queste mutazioni su cui ci concentreremo in questo capitolo.
  
Scriveremo alcune mutazioni per aggiungere nuove recensioni alla nostra applicazione. Gli utenti dell'API saranno in grado di creare nuove recensioni, lasciando una valutazione e un commento su repository.

#### Confronto tra Query e Mutazioni in GraphQL

Prima di addentrarci nell'aggiunta di mutazioni alla nostra applicazione, diamo uno sguardo alle differenze di sintassi tra le query e le mutazioni nelle API GraphQL. Quando eseguiamo un'operazione di query in GraphQL, utilizziamo la sintassi delle query:

```ruby
query {
    repos {
        name
        url 
    }
}
```

Questo indica a GraphQL che desideriamo recuperare alcune informazioni dalla nostra API. 

Quando eseguiamo un'operazione di mutazione in GraphQL, utilizziamo la sintassi delle mutazioni:

```ruby
mutation {
    addReview(
        input: {
            repoId: 1,
            rating: 5,
            comment: "My most favorite"
        }
    ) {
    id
    }
}
```

Questa sintassi indica all'API che desideriamo eseguire un'operazione di mutazione con il nome di addReview. Questa mutazione accetta alcuni input, che puoi pensare come i parametri di un modulo da una tipica sottomissione di un modulo Rails. La mutazione quindi svolge le sue funzioni e, una volta completata, chiediamo alla mutazione di restituirci l'ID della nuova recensione creata.

#### Creare recensioni tramite una mutazione
Come al solito, prima di iniziare a scrivere il codice per qualsiasi cosa, inizieremo con un test.

`spec/requests/graphql/mutations/reviews/add_spec.rb`

```ruby
require 'rails_helper'
RSpec.describe "GraphQL, addReview mutation" do
    let!(:repo) { Repo.create!(name: "Repo Hero", url:
    "https://github.com/repohero/repohero") }

    let(:query) do
    <<~QUERY
        mutation ($id: ID!, $rating: String!,$comment:String!) {
            addReview(input: { repoId: $id, rating: $rating, comment: $comment })
            {
                id
            }
        }
    QUERY
    end
    it "adds a new review" do
    post "/graphql", params: { 
        query: query,
        variables: {
            id: repo.id,
            rating: 5,
            comment: "What a repo!"
        }
    }

    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
        "addReview" => {
            "id" => Review.last.id.to_s,
            "rating" => "5",
        }
    )
    end
end

```

Questo test funziona allo stesso modo del nostro test per le query GraphQL. Definiamo un'operazione GraphQL che desideriamo eseguire in quella sintassi di stringa multiriga, quindi facciamo una richiesta POST a /graphql per inviarla alla nostra applicazione. La query rappresenta l'operazione GraphQL, mentre le variabili sono i valori che saranno passati alla nostra mutazione.

Quando eseguiamo questo test con `"bundle exec rspec spec/requests/graphql/mutations/reviews/add_spec.rb"`,

Otteniamo degli errori:

Questo ci sta dicendo che non abbiamo un campo chiamato addReview nel tipo Mutation definito dalla nostra API. Infatti, non lo abbiamo! In precedenza, aggiungevamo nuovi campi alla nostra classe QueryType. Tuttavia, poiché si tratta di una mutazione, dobbiamo aggiungerlo alla classe MutationType della nostra API.

`app/graphql/types/mutation_type.rb`

```ruby
module Types
    class MutationType < Types::BaseObject
        field :add_review, mutation: Mutations::Reviews::Add
    end
end
```

Definiamo i campi nel nostro tipo di mutazione con un metodo field, proprio come facciamo nel nostro tipo di query. Tuttavia, la differenza qui è che, anziché definire come il campo viene risolto all'interno della classe MutationType stessa, invece definiremo questa logica in una classe separata.

Definiamo ora questa classe `Reviews::Add`:

`app/graphql/mutations/reviews/add.rb`

```ruby
module Mutations
    module Reviews
        class Add < BaseMutation
            type Types::ReviewType, null: false
            argument :repo_id, ID, required: true
            argument :rating, String, required: true
            argument :comment, String, required: true

            def resolve(repo_id:, rating:, comment:)
                Review.create!(
                repo_id: repo_id,
                rating: rating,
                comment: comment,
                )
            end
        end
    end
end
```

Questa classe eredita da una classe fornita dalla libreria: BaseMutation. La classe BaseMutation imposta alcuni valori predefiniti per le mutazioni all'interno di questa applicazione.

All'interno della classe Reviews::Add, iniziamo definendo il tipo di ritorno della mutazione. Ogni volta che creiamo una recensione, rappresenteremo i dati di quella recensione con la nostra classe GraphQL ReviewType. Successivamente, definiamo gli argomenti per la mutazione utilizzando gli stessi metodi che abbiamo usato per definire gli argomenti delle query.

Infine, definiamo come risolvere questa mutazione definendo un metodo di risoluzione (resolve method). Questo metodo accetta gli argomenti della mutazione come argomenti con nome in Ruby e utilizza questi argomenti per creare un nuovo oggetto di modello Review utilizzando il metodo create! di Active Record.

Eseguiamo nuovamente il nostro test con "bundle exec rspec spec/requests/graphql/mutations/reviews/add_spec.rb".

La mutazione viene eseguita con successo, ma quando sta cercando di risolvere la nuova recensione creata, il tipo GraphQL Review non ha quel campo "id" che stiamo richiedendo. Aggiungiamolo ora:

`app/graphql/types/review_type.rb`
```ruby
module Types
    class ReviewType < Types::BaseObject
        field :id, ID, null: false
        field :rating, Integer, null: false
        field :comment, String, null: false
    end
end
```

#### Aggiornamento di una recensione
Potresti chiederti quale sia la sintassi per aggiornare una recensione. È diversa da quella per aggiungere una recensione? Buone notizie: non è enormemente diversa. Scriviamo un test per l'aggiornamento di una recensione tramite una mutazione:"

`spec/requests/graphql/mutations/reviews/update_spec.rb`

```ruby
require 'rails_helper'
RSpec.describe "GraphQL, updateReview mutation" do
    let!(:repo) { Repo.create!(name: "Repo Hero", url:
    "https://github.com/repohero/repohero") }

    let!(:review) { repo.reviews.create!(comment: "Kind of good", rating: 3)
    }

    it "edits an existing review" do
        query = <<~QUERY
        mutation ($id: ID!, $rating: String!,$comment:String!) {
            updateReview(input: { reviewId: $id, rating: $rating, comment: $comment }) {
                rating
                comment
         }
        }
        QUERY

        post "/graphql", params: {
            query: query,
            variables: {
                id: repo.id,
                rating: 5,
                comment: "On further thought, amazing!"
            }
        }

        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to eq(
            "updateReview" => {
            "rating" => 5,
            "comment" => "On further thought, amazing!"
        }
        )

    end
end
```

"Questa volta la mutazione accetta un ID della recensione, invece di un ID del repository. Accetta inoltre la valutazione e il commento, poiché sono i campi nella recensione che desideriamo aggiornare. La mutazione restituirà quindi la valutazione e il commento aggiornati una volta completato l'aggiornamento."

"Eseguiamo il nostro test con bundle exec rspec spec/requests/graphql/mutations/reviews/update_spec.rb per scoprire cosa dobbiamo fare."

"Il campo updateReview manca dal nostro tipo Mutation. Aggiungiamolo ora sotto il campo per l'aggiunta di una recensione:"

`app/graphql/types/mutation_type.rb`

```ruby
module Types
    class MutationType < Types::BaseObject
        field :add_review, mutation: Mutations::Reviews::Add
        field :update_review, mutation: Mutations::Reviews::Update
    end
end
```
"Ora che abbiamo aggiunto il campo updateReview alla nostra classe MutationType, aggiungiamo la classe che risolverà questa mutazione:"

`app/graphql/types/mutations/reviews/update.rb`

```ruby
module Mutations
    module Reviews
        class Update < BaseMutation
            type Types::ReviewType
            argument :review_id, ID, required: true
            argument :rating, String, required: true
            argument :comment, String, required: true

            def resolve(review_id:, rating:, comment:)
                Review.find(review_id).tap do |review|
                    review.update!(
                    rating: rating,
                    comment: comment
                    )
                end
            end
        end
    end
end

```

"Questo tipo di mutazione è definito in modo quasi identico al nostro tipo Reviews::Add. La differenza qui è che troviamo una recensione esistente anziché crearne una nuova. Una volta ottenuta la recensione esistente, chiamiamo update! su quella recensione per aggiornarne gli attributi. La mutazione quindi presenta questo oggetto Review aggiornato utilizzando la classe GraphQL ReviewType. Questa classe ci consente di selezionare i campi rating e comment dalla recensione aggiornata. Eseguendo nuovamente il nostro test, vedremo che ora è superato."

#### Eliminare una recensione
Come esercizio finale per le mutazioni, e per completezza, vediamo ora come possiamo eliminare una recensione esistente utilizzando una mutazione. Forse una delle nostre recensioni proviene da un spammer malizioso e dobbiamo eliminare la sua "preziosa contribuzione" dal sistema. Aggiungiamo prima un test:

`spec/requests/graphql/mutations/reviews/delete_spec.rb`

```ruby
require 'rails_helper'
RSpec.describe "GraphQL, deleteReview mutation" do
    let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }
    let!(:review) { repo.reviews.create!(comment: "Spammy spam spam spam", rating: 1) }

    it "deletes an existing review" do
        query = <<~QUERY
            mutation ($id: ID!) {
                deleteReview(input: { reviewId: $id }) {
                    id
                }
            }
        QUERY
    
        post "/graphql", params: {
            query: query,
            variables: {
            id: repo.id,
            }
        }

        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to eq(
            "deleteReview" => {
            "id" => review.id.to_s,
            }
        )
        end
end


```


Come in precedenza con i nostri test di creazione e aggiornamento, quando eseguiamo questo test con il comando bundle exec rspec spec/requests/graphql/mutations/delete_review_spec.rb, vedremo che esso fallisce.


Iniziamo ad aggiungere questo campo alla nostra API GraphQL adesso. Inizieremo aprendo la classe MutationType e aggiungendo il campo:

`app/graphql/types/mutation_type.rb`

```ruby
module Types
    class MutationType < Types::BaseObject
        field :add_review, mutation: Mutations::Reviews::Add
        field :update_review, mutation: Mutations::Reviews::Update
        field :delete_review, mutation: Mutations::Reviews::Delete
    end
end
```

E successivamente dovremo definire la classe che si occupa dell'eliminazione di una recensione:

`app/graphql/types/mutations/reviews/delete.rb`

```ruby
module Mutations
    module Reviews
        class Delete < BaseMutation
            type Types::ReviewType
            argument :review_id, ID, required: true

            def resolve(review_id:)
                Review.find(review_id).destroy
            end
        end
    end
end
```

Questa mutazione non ha bisogno di ricevere gli argomenti di valutazione e commento come le nostre ultime due mutazioni. Invece, prendiamo l'ID di una recensione, la troviamo e la eliminiamo. Addio, spammer cattivo!
Ora eseguiamo di nuovo il nostro test e verifichiamo se abbiamo posizionato tutto al posto giusto.

Fantastico! Ora siamo in grado di non solo creare e aggiornare recensioni nella nostra app, ma anche eliminarle.