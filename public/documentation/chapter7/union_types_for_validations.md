#### Tipi union per le validazioni

Nei due capitoli precedenti, abbiamo trattato i tipi union e le mutazioni. In questo capitolo, uniremo entrambi questi concetti per gestire mutazioni che possono avere successo o fallire. Quando scriviamo la query GraphQL per utilizzare queste mutazioni, le scriveremo in questo modo:

```ruby
mutation ($id: ID!, $rating: ReviewRating!, $comment: String!) {
    addReview(input: { repoId: $id, rating: $rating, comment: $comment }) {
        ...on Review {
            id
            rating
        }
        ...on ValidationError {
            errors {
                fullMessages
                attributeErrors {
                    attribute
                    errors
                }
            }
        }
    }
}

```

Se l'aggiunta di una recensione supera tutte le sue validazioni, otterremo il tipo Review. Se fallisce, otterremo invece il tipo `ValidationError`. Questo tipo di errore di validazione conterrà una chiave `fullMessages` che conterrà un elenco leggibile dall'essere umano degli errori riscontrati:

```sh
["Comment can't be blank"]
```

Mentre la chiave `attributeErrors` conterrà un elenco di errori per ciascun attributo che non ha superato la validazione:

```ruby
[
    {
    "attribute": "comment",
    "errors": ["can't be blank"]
    }
]
```

Ho scelto questa struttura perché talvolta gli utenti dell'API potrebbero desiderare di visualizzare i messaggi di errore nella parte superiore del modulo in un elenco. Oppure, alternativamente, potrebbero desiderare di visualizzare i messaggi di errore per ciascun attributo sotto il campo corrispondente nel modulo. Questa struttura consente entrambi questi casi d'uso.

#### Prepariamoci le validazioni

Prima di poter far sì che la nostra API GraphQL mostri messaggi di validazione, dobbiamo applicare queste validazioni nel nostro modello di recensione. Aggiungiamo due nuove validazioni al modello di recensione per garantire la presenza sia di valutazioni che di commenti, e che le valutazioni debbano essere comprese tra 1 e 5:

`app/models/review.rb`

```ruby
class Review < ApplicationRecord
    belongs_to :repo
    
    validates :rating, presence: true, numericality: { in: 1..5 }
    validates :comment, presence: true
end
```

Ora, se tentiamo di creare una recensione con una valutazione o un commento non validi, Active Record impedirà che tali recensioni vengano salvate nel database. 
L'ultima cosa che dobbiamo fare per preparare il terreno è aggiornare il nostro test per l'aggiunta di una recensione. Andiamo nel file `spec/requests/graphql/mutations/reviews/add.rb` e aggiorniamo la query all'inizio di questo file in modo che ora gestisca una risposta di tipo union dalla mutazione:

`spec/requests/graphql/mutations/reviews/add.rb`

```ruby
 let(:query) do
    <<~QUERY
        mutation ($id: ID!, $rating: String!,$comment:String!) {
            addReview(input: { repoId: $id, rating: $rating, comment: $comment }) {
                {
                    id
                    rating
                }

                ...on ValidationError {
                    errors {
                        fullMessages
                        attributeErrors {
                            attribute
                            errors
                        }
                    }
                }
            }
        }
    QUERY
    end

```

Infine, dovremo aggiungere un test aggiuntivo a questo file per verificare cosa accade quando viene creata una recensione non valida. Per questo caso di test, forniremo una valutazione, ma lasceremo il commento vuoto:

```ruby
 it "cannot add a review without a comment" do
        post "/graphql", params: {
            query: query,
            variables: {
                id: repo.id,
                rating: "FIVE_STARS",
                comment: ""
            }
        }

        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to eq(
            "addReview" => {
                "errors" => {
                    "fullMessages" => ["Comment can't be blank"],
                    "attributeErrors" => [
                        {
                            "attribute" => "comment",
                            "errors" => ["can't be blank"],
                        }
                    ]
                }
            }
        )
    end

```

Quando eseguiamo questo test con `bundle exec rspec spec/requests/graphql/mutations/reviews/add.rb`, vedremo che fallisce:

```sh
...
    "message": "No such type ValidationError, so it can't be a fragment condition",
...

```

Questo accade perché non abbiamo ancora definito il tipo `ValidationError` o, in effetti, nessun comportamento per gestire gli errori di validazione nella nostra API GraphQL.

#### Aggiunta di un tipo "ValidationError"
Questo tipo di errore di validazione rappresenterà un'occorrenza di validazione non riuscita nella nostra API GraphQL. Il tipo che dobbiamo definire rappresenterà questa parte della query GraphQL

```ruby
...on ValidationError {
    errors {
        fullMessages
        attributeErrors {
            attribute
            errors
        }
    }
}
...
```

Per definire questo tipo, creeremo un nuovo file in `app/graphql/types/validation_error_type.rb`. Inizieremo definendo il campo di livello superiore chiamato `errors`.

`app/graphql/types/validation_error_type.rb`

```ruby
module Types
    class ValidationErrorType < Types::BaseObject
        field :errors, Types::ValidationErrorType::Errors, null: false
    end
end
```

Questo campo rappresenterà il metodo `errors` che comunemente utilizziamo per accedere agli errori di validazione nelle istanze del modello all'interno di un'applicazione Rails. Definiremo questo campo come una nuova classe chiamata `Errors` all'interno della classe `ValidationErrorType`:

`app/graphql/types/validation_error_type.rb`

```ruby
module Types
    class ValidationErrorType < Types::BaseObject
        
        class Errors < Types::BaseObject
        end

        field :errors, Types::ValidationErrorType::Errors, null: false
    end
end
```

All'interno di questa nuova classe `Errors`, dobbiamo definire un campo chiamato `full_messages`. Questo sarà equivalente a chiamare `errors.full_messages` su un'istanza del modello e restituirà un array di stringhe che rappresentano i messaggi di errore completi per ciascun errore di validazione, come ad esempio `Comment can’t be blank`:

`app/graphql/types/validation_error_type.rb`

```ruby
module Types
    class ValidationErrorType < Types::BaseObject
        
        class Errors < Types::BaseObject
            field :full_messages, [String], null: false
        end

        field :errors, Types::ValidationErrorType::Errors, null: false
    end
end
```

Successivamente, dobbiamo definire un campo chiamato `attribute_errors` per restituire gli errori relativi agli attributi individuali. Gli utenti della nostra API potrebbero utilizzare questi messaggi di errore per visualizzare questi errori accanto al campo relativo all'attributo in un modulo. Questo campo restituirà un array di oggetti `AttributeError`:

`app/graphql/types/validation_error_type.rb`

```ruby
module Types
    class ValidationErrorType < Types::BaseObject

        class Errors < Types::BaseObject
            field :full_messages, [String], null: false
            field :attribute_errors, [Types::ValidationErrorType::AttributeError], null: false
        end
        field :errors, Types::ValidationErrorType::Errors, null: false
    end
end
```

Avremo bisogno di un metodo personalizzato per "attribute_errors", poiché la struttura che otterremmo da "errors.group_by_attribute" è un oggetto di tipo Hash, ma una struttura migliore per noi è un array. GraphQL non supporta chiavi dinamiche, che è ciò di cui avremmo bisogno per rappresentare un oggetto di tipo Hash.

`app/graphql/types/validation_error_type.rb`

```ruby
#...
    class Errors < Types::BaseObject
        field :full_messages, [String], null: false
        field :attribute_errors, [Types::ValidationErrorType::AttributeError], null: false

        def attribute_errors
            object.group_by_attribute.map do |attribute, errors|
                {
                    attribute: attribute,
                    errors: errors
                }
            end
        end

    end

#...
```
Infine, dobbiamo definire il tipo `AttributeError`. Questo tipo rappresenterà gli errori per un singolo attributo. Avrà due campi: `attribute` ed `errors`. Il campo `attribute` sarà una stringa che rappresenta il nome dell'attributo che non ha superato la validazione. Il campo "errors" sarà un array di stringhe che rappresentano i messaggi di errore per quell'attributo.

`app/graphql/types/validation_error_type.rb`

```ruby
class AttributeError < Types::BaseObject
    
    field :attribute, String, null: false
    field :errors, [String], null: false

    def errors
        object[:errors].map(&:message)
    end
end
```

Mettendo tutto questo insieme, otterremo questo tipo:

```ruby
module Types
    class ValidationErrorType < Types::BaseObject

        class AttributeError < Types::BaseObject
            field :attribute, String, null: false
            field :errors, [String], null: false

            def errors
                object[:errors].map(&:message)
            end
        end

        class Errors < Types::BaseObject
            field :full_messages, [String], null: false
            field :attribute_errors, [AttributeError], null: false

            def attribute_errors
                object.group_by_attribute.map do |attribute, errors|
                    {
                    attribute: attribute,
                    errors: errors
                    }
                end
            end
        end

        field :errors, Types::ValidationErrorType::Errors, null: false
    end
end
```

#### Gestione degli errori di validazione

Per utilizzare questo tipo, dovremo modificare la mutazione `addReview` in modo che restituisca un tipo union di `Review` o `ValidationError`. Per fare ciò, dovremo cambiare il valore di ritorno del metodo `resolve` per indicare una risoluzione riuscita o una risoluzione fallita. Per supportare ciò, aggiungeremo una gemma chiamata `dry-monads` al progetto. 
Possiamo farlo eseguendo:

```sh
bundle add dry-monads
```

Questa gemma fornisce una serie di `monads` utili che possiamo utilizzare per rappresentare il successo o il fallimento della nostra mutazione. Utilizzeremo il monad `Dry::Monads::Result` per rappresentare il successo o il fallimento della nostra mutazione. Per utilizzare questa gemma, aggiungeremo questa direttiva `include` all'inizio della classe di mutazione `Reviews::Add`:


```ruby
module Mutations
    module Reviews
        class Add < BaseMutation
            include Dry::Monads[:result]
            type Types::ReviewType, null: false
            argument :repo_id, ID, required: true
            argument :rating, String, required: true
            argument :comment, String, required: true

            def resolve(repo_id:, rating: , comment:)
                review = Review.create!(
                    repo_id: repo_id,
                    rating: rating,
                    comment: comment,
                )

                if review.save
                    Success(review)
                else
                    Failure(review)
                end
            end
        end
    end
end
```
I metodi di successo e fallimento sono forniti dalla gemma `Dry::Monads`. Se la recensione viene salvata con successo, restituiamo una monade `Success` con la recensione come valore. Se la recensione non viene salvata con successo, restituiamo una monade `Failure` con la recensione come valore. 
Possiamo quindi utilizzare queste monadi di risultati per risolvere un tipo di unione in `ReviewType` o un `ValidationErrorType`, definendo questo tipo di unione in `app/graphql/types/add_review_result.rb`:

```ruby
module Types
    class AddReviewResult < Types::BaseUnion
        possible_types Types::ReviewType, Types::ValidationErrorType
    
        def self.resolve_type(object, context)
            if object.success?
                [Types::ReviewType, object.success]
            else
                [Types::ValidationErrorType, object.failure]
            end
        end
    end
end

```

Se l'oggetto è incapsulato in una monade `Success`, allora success? restituirà true. In questo caso, definiamo il tipo che viene risolto qui utilizzando un array. Il primo elemento dell'array indica che vogliamo utilizzare la classe `Types::ReviewType` per risolvere questo campo. 
Il secondo elemento è object.success, che `scompone` la recensione dalla monade e ci restituisce un oggetto di tipo Review.

Se la validazione `fallisce`, verrà utilizzata la nuova classe `Types::ValidationErrorType` per risolvere questo campo, `scomponendo` nuovamente la recensione in modo che possiamo accedere ai suoi errori.

Successivamente, dobbiamo aggiornare la mutazione `Reviews::Add` per utilizzare questo nuovo tipo di unione:

```ruby
module Mutations
    module Reviews
        class Add < BaseMutation
            include Dry::Monads[:result]

            type Types::AddReviewResult, null: false

            type Types::ReviewType, null: false
            argument :repo_id, ID, required: true
            argument :rating, String, required: true
            argument :comment, String, required: true

            def resolve(repo_id:, rating: , comment:)
                review = Review.create!(
                    repo_id: repo_id,
                    rating: rating,
                    comment: comment,
                )

                if review.save
                    Success(review)
                else
                    Failure(review)
                end
            end
        end
    end
end

```

L'utilizzo di questo tipo farà sì che la mutazione `addReview` venga risolta utilizzando un tipo di unione. Se il salvataggio di una recensione ha successo, il campo verrà risolto utilizzando `ReviewType` come prima. Se non riesce a superare la validazione, verrà risolto utilizzando `ValidationErrorType` che abbiamo appena definito.

Eseguiamo nuovamente i nostri test con `bundle exec rspec spec/graphql/mutations/add_review_spec.rb`. Questa volta vedremo che il nostro test per l'aggiunta di una recensione supera con successo, così come il nostro nuovo test per la gestione degli errori di validazione.

Abbiamo visto come gestire gli errori di validazione in GraphQL. Abbiamo affrontato solo la validazione relativa all'aggiunta di una recensione in questo caso, ma è possibile estendere il sistema per gestire gli errori di validazione per qualsiasi altra mutazione nel sistema