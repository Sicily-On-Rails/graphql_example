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

Questa classe di mutazione definisce il comportamento per risolvere la mutazione di registrazione. Tenterà di creare un utente nel modo tradizionale di Rails: chiamando il metodo `create` su un modello. Quando questa mutazione viene risolta, userà il tipo `SignupResult` per rappresentare il risultato di questa mutazione. Definiamo questo tipo ora:

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

Questo tipo definisce i campi che saranno restituiti quando la mutazione viene risolta. L'oggetto che questo tipo utilizzerà è un'istanza di `Utente`. Questa istanza dovrebbe avere un campo `email` che possiamo utilizzare in questo tipo `SignupResult`. Il campo del token è un po' più complicato da implementare, quindi metteremo un valore fittizio per ora in modo da poter vedere il superamento del nostro test. Torneremo più avanti per definire un token appropriato.
Con tutta questa configurazione, ora il nostro test passerà:

`bundle exec rspec spec/requests/graphql/mutations/users/sign_up_spec.rb`

```sh
1 example, 0 failures
```
#### Gestione delle registrazioni non valide
Ora che abbiamo gestito il percorso valido per la registrazione di un utente, vediamo cosa succede quando un utente si registra con dati non validi, come un indirizzo email mancante. Inizieremo scrivendo un test per questo:

```ruby
#...
it "cannot sign up with a missing email" do
    post "/graphql", params: { 
        query: query,
            variables: {
            name: "Test User",
            email: "",
            password: "SecurePassword1",
            password_confirmation: "SecurePassword1",
        }
    } 
    expect(response.parsed_body).not_to have_errors
        signup = response.parsed_body["data"]["signup"]
        expect(signup).to eq(
            "errors" => {
            "fullMessages" => ["Email can't be blank"],
            "attributeErrors" => [
                {
                "attribute" => "email",
                "errors" => ["can't be blank"],
                }
            ]   
        }
    )
end
#...
```

Questo test cercherà di registrare un utente con un indirizzo email vuoto, e quando ciò accade, la mutazione dovrebbe rispondere con un tipo di convalida.
Per far sì che ciò funzioni correttamente, dovremo aggiornare la query in cima a questo file per gestire i casi di successo e insuccesso:

```ruby
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
                  ...on User {
                        email
                        token
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

La nostra query indica ora che il campo di registrazione restituisce un tipo di unione, in cui il tipo restituito può essere sia AuthenticatedUser che ValidationError. Attualmente, il nostro tipo SignupResult restituisce solo un singolo tipo. Dovremo modificarlo. Cambiamo il codice nella classe SignupResult in modo che ora restituisca questa unione:

`app/graphql/types/signup_result.rb`

```ruby
module Types
    class SignupResult < BaseObject
        possible_types Types::AuthenticatedUserType, Types::ValidationErrorType
        def self.resolve_type(object, _context)
            if object.success?
                [Types::AuthenticatedUserType, object.success]
            else
                [Types::ValidationErrorType, object.failure]
            end
        end
    end
end
```
Il codice che era precedentemente presente in questo file sarà ora spostato in una classe unica per gli utenti, una classe chiamata `Types::AuthenticatedUserType`:

`app/graphql/types/user_type.rb`

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

Stiamo utilizzando il nome di classe `AuthenticatedUserType` invece di `UserType` perché vogliamo una classe che rappresenti in modo univoco gli utenti autenticati all'interno della nostra applicazione. In seguito, vorremo una classe che non contenga la capacità di restituire un token di autenticazione, e per quella useremo una classe `UserType`.

Per consentire a `SignupResult` di determinare quale tipo utilizzare, dovremo apportare una piccola modifica al `resolver` della mutazione stessa. Questo `resolver` dovrà ora restituire un oggetto `Success` o `Failure`, a seconda che si riesca a salvare l'utente o meno.

`app/graphql/mutations/users/signup.rb`

```ruby
def resolve(name:, email:, password:, password_confirmation:)
    user = User.new(
        name: name,
        email: email,
        password: password,
        password_confirmation: password_confirmation
    )

    if user.save
        Success(user)
    else
        Failure(user)
    end
end

```

Quando il nostro test cerca di creare un utente senza un indirizzo email, questa mutazione restituirà un oggetto `Failure(user)`. Questo causerà la restituzione di un oggetto `Types::ValidationErrorType` da parte del tipo `SignupResult`, mostrando l'errore di convalida come risposta alla chiamata dell'API GraphQL.

Eseguiamo di nuovo questo file di test. Ora dovrebbe superare il test con successo.

```sh
2 examples, 0 failures
```

Gli utenti ora possono registrarsi nella nostra applicazione tramite la nostra API GraphQL. In caso di inserimento di dettagli non validi, l'API informerà l'utente indicando gli errori commessi.

#### Logging in

Consentire agli utenti di registrarsi è ottimo, ma vogliamo che i nostri utenti continuino a tornare su Repo Hero e a recensire i repository. Per permettere a questi utenti di accedere nuovamente, avremo bisogno di un modo per autenticarli quando ritornano. Lo faremo consentendo loro di effettuare l'accesso con il loro indirizzo email e password. Quando forniranno un indirizzo email e una password validi, forniremo loro un token speciale che potranno utilizzare per autenticarsi in future richieste.

La mutazione per l'accesso sarà molto simile alla mutazione per la registrazione:

```ruby
mutation login($email: String!, $password: String!) {
    login(
        input: {
        email: $email,
        password: $password,
        }
    ) {
        ...on AuthenticatedUser {
            email
            token
        }
        ...on FailedLogin {
            error
        }
    }
    }
}
```

Questa mutazione restituirà un tipo `User` o `FailedLogin`, a seconda se l'utente può essere autenticato o meno.

Cominciamo scrivendo un test per il percorso di successo di questa mutazione:

`spec/requests/graphql/mutations/users/login_spec.rb`

scriviamo il test:
..... 

Questo test inizia creando un utente con cui possiamo effettuare l'accesso. Successivamente, definiamo la query della mutazione e la eseguiamo nell'esempio. Quando la eseguiamo, forniamo i valori corretti per l'indirizzo email e la password dell'utente, quindi ci aspettiamo di ricevere una risposta positiva. Eseguiamo questo test e vediamo se fallisce:

...log del test che fallisce ...


Come potremmo aver imparato finora, il test sta fallendo perché il nostro campo di accesso non esiste. Aggiungiamo questo campo sotto il campo di `registrazione` nella nostra classe MutationType

```ruby
module Types
class MutationType < Types::BaseObject
    # ...
    field :signup, mutation: Mutations::Users::Signup
    field :login, mutation: Mutations::Users::Login
    end
end

```

Successivamente, definiremo la classe di mutazione stessa:

`app/graphql/mutations/users/login.rb`

... scrivere la classe ...


Questa mutazione prende in input gli argomenti email e password e utilizza il metodo authenticate fornito dall'estensione has_secure_password nel nostro modello User per autenticare l'utente. Tale metodo restituirà un oggetto User se l'autenticazione è riuscita, altrimenti restituirà nil.

Per gestire il successo o il fallimento di questa mutazione, utilizziamo la classe LoginResult... che attualmente non è definita. Quindi andiamo avanti e definiamola ora

`app/graphql/types/login_result.rb`

....
aggiungere da libro
...


Questo tipo di unione gestirà il successo o il fallimento della mutazione. Se l'accesso è avvenuto con successo, verrà utilizzata la classe `AuthenticatedUserType` per risolvere il risultato. In caso contrario, verrà utilizzata `FailedLoginType`.

Al momento, non abbiamo ancora il tipo FailedLoginType, quindi andiamo avanti e creiamolo ora.

`app/graphql/types/failed_login_type.rb`

Questo tipo restituisce un messaggio di errore semplice (ma vago) per indicare un'autenticazione fallita.

Questo è tutto ciò che è necessario per configurare la nostra mutazione. Andiamo avanti ed eseguiamo il test per vedere se ora passa.

```sh
1 example, 0 failures
```

Ottimo! Ora abbiamo un modo per effettuare l'accesso degli utenti attraverso la nostra API GraphQL. Prima di proseguire, sarebbe un errore non coprire anche lo scenario di fallimento nei nostri test. Aggiungiamo un test a `login_spec.rb` per coprire questo caso:

....
aggiungere test da libro
....

Questo è un test rapido per assicurarsi che quando un utente inserisce una password non valida, il tipo GraphQL restituito sia `FailedLoginType`. Eseguiamo questo test e verifichiamo che passi

```sh
2 examples, 0 failures
```
"Se ti aiuta a dormire di notte, potresti anche aggiungere un altro test qui per verificare cosa succede se un utente fornisce un indirizzo email non valido, ma una password valida.

... aggiungere test da libro ... 

#### Utilizzo di token per l'autenticazione

Ora che i nostri utenti possono accedere alla nostra applicazione tramite GraphQL, come facciamo in modo che possano rimanere connessi? Tipicamente, in un'applicazione Rails, restituiremmo un cookie all'utente che lo invierebbe poi in futuri richieste. Potremmo fare lo stesso con la nostra API GraphQL, ma ciò richiederebbe di ispezionare quale operazione viene eseguita e restituire un cookie solo se si tratta di un'operazione di accesso o registrazione. Questo sarebbe un po' complicato da implementare, quindi invece opteremo per un approccio diverso: utilizzeremo un JSON Web Token (JWT).

Un JWT è una stringa che contiene informazioni sull'utente che possiamo utilizzare per autenticarli in future richieste. Questa stringa è cifrata in modo che l'utente non possa manometterla. Al momento, dopo che un utente si registra o accede, utilizziamo l'oggetto UserType per restituire un token fittizio:

`app/graphql/types/authenticated_user_type.rb`
```ruby
def token
    "abc1234"
end
```
Questo token non è univoco per ciascun utente e, peggio ancora, non è criptograficamente sicuro. Questa stringa non va bene come mezzo per autenticare gli utenti per le richieste future. Invece di questa stringa, genereremo qui un JWT. Un esempio di JWT è il seguente (con l'aggiunta di spazi per farlo stare nella pagina)

```sh
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0Ijo
xNTE2MjM5MDIyfQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

"Un JWT è suddiviso in tre parti distinte separate da punti:

* Un'intestazione che indica come è cifrato il carico utile.
* Un carico utile che contiene le informazioni che vogliamo cifrare.
* Una firma che viene utilizzata per verificare che il carico utile non sia stato manomesso.

Per generare JWT, di solito utilizziamo la gemma jwt in Ruby. Tuttavia, trovo che l'API di questa gemma sia un po' scomoda, quindi ho scritto un'altra gemma chiamata jot-helpers che semplifica queste chiamate. Possiamo installare questa gemma con:"

```sh
bundle add jot-helpers
```

Questa gemma ci richiede di configurare l'algoritmo che vogliamo utilizzare per cifrare i nostri JWT. Possiamo farlo creando un file chiamato `config/initializers/jot.rb` e aggiungendo questo codice al suo interno

```ruby
Jot.configure do |config|
    config.algorithm = "HS256"
    config.secret = <a really long secret generated by "rails secret">
end
```

Questa configurazione utilizzerà l'algoritmo HS256 per cifrare i nostri JWT con il valore dell'hash molto lungo che abbiamo fornito qui. Per utilizzare questa gemma all'interno della nostra applicazione per generare token, possiamo sostituire il metodo token all'interno di UserType:

`app/graphql/types/authenticated_user_type.rb`

```ruby
def token
    Jot.encode(email: object.email)
end
```

Questo genererà un JWT che contiene l'indirizzo email dell'utente. Possiamo quindi utilizzare questo JWT per autenticare l'utente nelle richieste future. Se ora eseguiamo i nostri test, vedremo che stanno ancora passando

```sh
18 examples, 0 failures ###da verificare
```

Il nostro test di accesso sta ancora passando, ma ora restituisce un JWT invece della stringa fittizia che avevamo prima. Per utilizzare questo JWT, dovremo leggere questo token ogni volta che viene passato in una richiesta GraphQL. Per assicurarci che questa funzionalità funzioni, aggiungeremo un nuovo campo al nostro tipo di query GraphQL chiamato 'me'. Questo restituirà informazioni sull'utente attualmente connesso, indicando che la nostra autenticazione funziona.

Iniziamo scrivendo un test per questo:
`spec/requests/graphql/queries/me_spec.rb`

... scrivere il test ...

Questo test utilizza un nuovo campo chiamato 'me' per recuperare le informazioni dell'utente corrente. L'utente corrente è identificato da un'intestazione di autorizzazione che assomiglierà a questa:

```sh
Bearer eyJ...
```

Quest'intestazione contiene il JWT che è stato generato utilizzando Jot.encode. Possiamo utilizzare questo JWT per identificare l'utente che sta effettuando la richiesta. Eseguiamo questo test e vediamo se fallisce.

```sh
GraphQL, me query fetches the current user's information
    Failure/Error: expect(response.parsed_body).not_to have_errors
    Expected there to be no errors, but there were:
    [
        {
            "message": "Field 'me' doesn't exist on type 'Query'",

```
Certo! Al momento non abbiamo ancora il campo 'me'. Aggiungiamolo alla nostra classe QueryType:

`app/graphql/types/query_type.rb`

```ruby
field :me, AuthenticatedUserType, null: true
def me
    context[:current_user]
end
```
GraphQL ci permette di utilizzare un metodo chiamato 'context' per accedere al contesto di una richiesta. Il contesto è definito quando chiamiamo il nostro codice GraphQL in GraphqlController, ma attualmente è definito come un hash vuoto:

`app/controllers/graphql_controller.rb`
```ruby
context = {
# Query context goes here, for example:
# current_user: current_user,
}
```

Questo valore viene quindi passato al metodo 'execute' insieme alla query e alle variabili per la nostra richiesta
```ruby
result = RepoHeroSchema.execute(
    query,
    variables: variables,
    context: context,
    operation_name: operation_name
)
```

Al momento non abbiamo ancora un modo per impostare il valore di 'current_user' in questo contesto, quindi aggiungiamolo ora. Lo faremo definendo un metodo 'current_user'. Questo metodo dovrà estrarre il token dall'intestazione di autorizzazione e quindi decodificare il token per trovare l'indirizzo email all'interno di esso. Una volta ottenuto l'indirizzo email, possiamo quindi trovare l'utente corrispondente a quell'indirizzo email e restituirlo:

`app/controllers/graphql_controller.rb`

```ruby
def current_user
    return if request.headers["Authorization"].blank?

    bearer_token = request.headers["Authorization"].match("Bearer (.*)$")[1]
    if bearer_token
        payload = Jot.decode(bearer_token)
        return User.find_by(email: payload["email"])
    end
end
```

Questo metodo restituirà l'utente attualmente connesso o nil se non c'è alcun utente connesso. Possiamo quindi utilizzare questo metodo per impostare il valore di 'current_user' nel contesto:

`app/controllers/graphql_controller.rb`

```ruby
    context = {
        current_user: current_user,
    }
```
"Eseguiamo di nuovo il nostro test e verifichiamo che passi:"

```sh
1 example, 0 failures
```
Ottimo! Ora possiamo passare un token JWT alla nostra API GraphQL e far sì che l'API riconosca quale utente è connesso.