 #### Autenticazione
In questo capitolo affronteremo l'autenticazione. Quando un utente si autentica con l'app Repo Hero e poi utilizza l'API GraphQL per creare una recensione, collegheremo quel record di recensione all'utente che l'ha creato.

Prima che un utente possa autenticarsi, avranno bisogno di un modo per registrarsi come utente dell'applicazione, ed è da qui che inizieremo questo capitolo. Per rappresentare gli utenti all'interno della nostra applicazione, alla fine definiremo un modello di Utente e utilizzeremo la funzionalità built-in has_secure_password di Rails per salvare in modo sicuro la password di quell'utente e per autenticarlo.

Quando un utente si registra nella nostra applicazione, richiederemo loro di fornirci un indirizzo email, una password e una conferma della password. Per supportare tutto ciò, creeremo innanzitutto un modello per rappresentare il nostro utente.

#### Creazione di un modello utente
Questo modello utente dovrà avere tre campi distinti: nome, email e password_digest. Il campo password_digest è dove la nostra app memorizzerà la password dell'utente criptata, con l'aiuto della funzionalità has_secure_password di Rails.
Generiamo ora questo modello con questo comando:

```sh
rails g model user name:string email:string password_digest:string
```

Questo genererà il modello, una migrazione ed un file di test per il modello. Non abbiamo bisogno del file `spec/models/user_spec.rb`, quindi puoi eliminarlo.
Successivamente, possiamo eseguire la migrazione generata:

```sh
rails db:migrate
```

Adesso, configureremo il modello per cifrare automaticamente la password dell'utente quando viene impostata. Possiamo farlo aggiungendo la linea `has_secure_password` al modello. 
Verificheremo che il loro indirizzo email sia presente e unico. Confermeremo inoltre la presenza del loro nome.

`app/models/user.rb`

```ruby
class User < ApplicationRecord
    has_secure_password
    validates :email, presence: true, uniqueness: true
    validates :name, presence: true
end
```

Il metodo `has_secure_password` gestirà la cifratura della password dell'utente e la memorizzerà nella colonna `password_digest`. Questa funzionalità ci fornirà anche un metodo chiamato `authenticate` che possiamo utilizzare per autenticare gli utenti quando abbiamo bisogno di farli accedere nuovamente.
L'ultima cosa che dobbiamo fare qui è aggiungere la gemma `bcrypt ` al nostro `Gemfile`. Questa gemma è ciò che `has_secure_password` utilizza per cifrare la password. Possiamo aggiungere questa gemma eseguendo questo comando:

```sh
bundle add bcrypt
```

Una volta installata questa gemma, possiamo assicurarci che tutto funzioni provando a creare un utente nella console di Rails. Avviala con il comando rails c e poi esegui questo comando:

```ruby
User.create!(
    name: "Test User",
    email: "test@example.com",
    password: "SecurePassword1",
    password_confirmation: "SecurePassword1"
)
```

Prossimo passo, vediamo come possiamo creare utenti tramite una mutazione GraphQL. Questa mutazione utilizzerà gran parte del codice della chiamata nella console di Rails, con alcune differenze che vedremo.


#### Registrazione degli utenti
La mutazione GraphQL per la registrazione di un utente sarà la seguente:

```ruby
mutation signup(
    $name: String!,
    $email: String!,
    $password: String!,
    $passwordConfirmation: String!
) {
    signup(
    input: {    
        name: $name,
        email: $email,
        passwordConfirmation: $passwordConfirmation,
    }
    ) {
        email
        token
    }
    }
```

Quando una registrazione ha successo, restituiremo l'indirizzo email dell'utente e un campo chiamato token. Questo token sarà un  Web Token JSON, una stringa criptata che contiene informazioni sull'utente che possiamo utilizzare per autenticarli in richieste future. Iniziamo scrivendo un test  della mutazione di registrazione e vediamo cosa succede quando un utente si registra con successo.

`spec/requests/graphql/mutations/users/sign_up_spec.rb`

```ruby
require 'rails_helper'
    RSpec.describe "GraphQL, signUp mutation", type: :request do
    let(:query) do
        <<~QUERY
            mutation signup($email: String!, $password: String!,$password_confirmation: String!) {
                signup(
                    input: {
                        email: $email,
                        password: $password,
                        passwordConfirmation: $password_confirmation,
                    }
                ) {
                    email
                    token
                }
            }
        QUERY
    end

    it "signs up a new user successfully" do
        post "/graphql", params: {query: query,
                variables: {
                    email: "test@example.com",
                password: "SecurePassword1",
                password_confirmation: "SecurePassword1",
            }
        }

        expect(response.parsed_body).not_to have_errors
        expect(response.parsed_body["data"]).to match(
            "signup" => {
            "email" => "test@example.com",
            }
        )
        expect(response.parsed_body["data"]["signup"]["token"]).to be_present
    end
end

```

Questo test utilizza la mutazione sopra descritta e cerca di registrare con successo un nuovo utente. Ci aspettiamo che la risposta contenga l'indirizzo email dell'utente e un token.

Eseguiamo questo test e verifichiamo che fallisca con il comando `bundle exec rspec spec/requests/graphql/mutations/users/sign_up_spec.rb`.

Questo errore ci sta dicendo che il campo di mutazione di registrazione non esiste. Aggiungiamo questa mutazione alla classe MutationType dell'applicazione ora:

`app/graphql/types/mutation_type.rb`

```ruby
field :signup, mutation: Mutations::Users::SignUp
```

Dovremo quindi creare la classe che verrà utilizzata per risolvere questa mutazione:
`app/graphql/mutations/users/sign_up.rb`

```ruby
module Mutations
    module Users
        class Signup < BaseMutation
            type Types::SignupResult, null: false
            argument :name, String, required: true
            argument :email, String, required: true
            argument :password, String, required: true
            argument :password_confirmation, String, required: true

            def resolve(name:, email:, password:, password_confirmation:)
                User.create(
                name: name,
                email: email,
                password: password,
                password_confirmation: password_confirmation
                )
            end
        end
    end
end
```

Questa classe di mutazione definisce il comportamento per risolvere la mutazione di registrazione. Tenterà di creare un utente nel modo tradizionale di Rails: chiamando il metodo create su un modello. Quando questa mutazione viene risolta, userà il tipo SignupResult per rappresentare il risultato di questa mutazione. Definiamo questo tipo ora:

`app/graphql/types/signup_result.rb`


```ruby
module Types
    class SignupResult < BaseObject
        field :email, String, null: true
        field :token, String, null: true

        def token
            "abc123"
        end
    end
end
```

Questo tipo definisce i campi che saranno restituiti quando la mutazione viene risolta. L'oggetto che questo tipo utilizzerà è un'istanza di Utente. Questa istanza dovrebbe avere un campo email che possiamo utilizzare in questo tipo SignupResult. Il campo del token è un po' più complicato da implementare, quindi metteremo un valore fittizio per ora in modo da poter vedere il superamento del nostro test. Torneremo più avanti per definire un token appropriato.
Con tutta questa configurazione, ora il nostro test passerà: