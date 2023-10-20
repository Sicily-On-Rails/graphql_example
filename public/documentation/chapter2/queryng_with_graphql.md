#### (Queryng)Interrogare con GraphQL

Con la nostra applicazione configurata per funzionare con GraphQL e con un modello Repo già in posizione, vediamo come possiamo utilizzare tale modello per recuperare dati dal nostro database e visualizzare queste informazioni tramite GraphQL.

#### Query per visualizzare tutti i repository

Per mostrare un elenco di repository dalla nostra tabella dei repos tramite l'API GraphQL, dovremo apportare alcune modifiche al nostro codice GraphQL.

> Affronteremo la risoluzione di questo problema, e di altri problemi in tutto il libro, scrivendo prima un test, assicurandoci che esso fallisca, e poi scriveremo il codice per far passare il test. Questo approccio è scelto perché è simile all'approccio che ci sarebbe richiesto se stessimo scrivendo del codice GraphQL di produzione in una vera applicazione Rails.

I test per il codice GraphQL vengono inseriti nella cartella `spec/requests`, poiché faremo richieste direttamente alla nostra applicazione e poi faremo delle asserzioni sulla risposta che otteniamo.

Scriveremo il nostro primo test in un nuovo file chiamato `spec/requests/graphql/queries/repos_spec.rb:`

`spec/requests/graphql/queries/repos_spec.rb`
```ruby
require 'rails_helper'

RSpec.describe "Graphql, repos query" do
  let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }

  it "retrieves a list of available repos" do
    query = <<~QUERY
    query {
      repos {
        name
        url
      }
    }
    QUERY

    post "/graphql", params: { query: query }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "repos" => [
        {
          "name" => repo.name,
          "url" => repo.url,
        }
      ]
    )
  end
end
```

In questo test impostiamo un repository che dovremmo vedere restituito tramite la nostra `API GraphQL`.
All'interno del test stesso, costruiamo una query per recuperare un elenco di repository insieme ai loro campi di nome e URL. Successivamente, effettuiamo una richiesta `POST` a `/graphql` con la nostra query, e ci aspettiamo di non trovare errori e di vedere il repository restituito qui nei dati.
Quando eseguiamo questo test con il comando `bundle exec rspec spec`, vedremo che al momento sta fallendo:

```sh
Failure/Error: expect(response.parsed_body["errors"]).to be_blank
```

L'output sotto quel messaggio è un po' difficile da leggere. Potremmo esaminarlo attentamente e vedere questo messaggio:

```sh
Field 'repos' doesn't exist on type 'Query'
```

Un altro modo sarebbe prendere la query dal nostro test e utilizzarla nel nostro file `graphql-test.rb`:

```ruby
query = <<~QUERY
    query {
        repos {
            name
            url
        }
    }
    QUERY
    
result = RepoHeroSchema.execute(query)
puts JSON.pretty_generate(result)
```

Possiamo quindi eseguire questo script con `rails runner graphql-test.rb` e vedere esattamente lo stesso output che il nostro test sta vedendo:

```sh
{
  "errors": [
    {
      "message": "Field 'repos' doesn't exist on type 'Query'",
      "locations": [
        {
          "line": 2,
          "column": 5
        }
      ],
      "path": [
        "query",
        "repos"
      ],
      "extensions": {
        "code": "undefinedField",
        "typeName": "Query",
        "fieldName": "repos"
      }
    }
  ]
}

```

Possiamo ottenere un tipo simile di output nel nostro test definendo un `matcher` personalizzato RSpec, e poi torneremo subito al codice `GraphQL`. Il codice di questo matcher personalizzato va in un nuovo file su:

`spec/support/matchers/have_errors.rb`

```ruby
RSpec::Matchers.define :have_errors do
    match do |response|
      response["errors"].present?
    end
  
    failure_message_when_negated do |response|
      "Expected there to be no errors, but there were:\n" +
        JSON.pretty_generate(response["errors"])
    end
  
    failure_message do |str|
      "Expected there to be errors, but there weren't"
    end
end
```

Per assicurarti che questo file venga caricato, toglieremo il commento da questa riga in `spec/rails_helper.rb`:
```ruby
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f|require f }
```

Per utilizzare il `matcher`, possiamo quindi modificare questa riga nel nostro test:

```ruby
expect(response.parsed_body["errors"]).to be_blank
```

Con questo:

```ruby
expect(response.parsed_body).not_to have_errors
```

Fare questo significa che ora avremo un output più ordinato nei risultati dei test falliti, e non dovremo alternare tra i nostri test e quel file `graphql-test.rb` solo per vedere una versione più leggibile dei nostri errori. 

Eseguiamo ora il test con `bundle exec rspec` e vediamo cosa succede. Ora vedremo un messaggio di errore molto più chiaro:

```sh
Failure/Error: expect(response.parsed_body).not_to have_errors

       Expected there to be no errors, but there were:
       [
         {
           "message": "Field 'repos' doesn't exist on type 'Query'",
           "locations": [
             {
               "line": 2,
               "column": 3
             }
           ],
           "path": [
             "query",
             "repos"
           ],
           "extensions": {
             "code": "undefinedField",
             "typeName": "Query",
             "fieldName": "repos"
           }
         }
       ]
```

Molto meglio! Ora possiamo vedere il messaggio di errore in modo molto più chiaro. Ora, come possiamo risolvere questo problema in modo che il nostro test venga eseguito con successo? L'indizio è nel messaggio di errore:

```sh
"Field 'repos' doesn't exist on type 'Query'"
```
Questo messaggio di errore ci indica che la query nel test si aspetta che ci sia un campo chiamato `repos` nel tipo `Query`. Questo tipo `Query` in GraphQL corrisponde al file `query_type.rb` situato nella cartella `app/graphql`.

`app/graphql/query_type.rb`
```ruby
module Types
    class QueryType < Types::BaseObject
        #...
        # TODO: remove me
        field :test_field, String, null: false,
        description: "An example field added by the generator"
        def test_field
        "Hello World!"
        end
    end
end
```
Adesso possiamo aggiungere il nostro campo `repos`

`app/graphql/query_type.rb`
```ruby
module Types
    class QueryType < Types::BaseObject
        # ...
        field :repos, [RepoType], null: false

        def repos
            Repo.all
        end
    end
end
```

Con queste modifiche, stiamo definendo il campo `repos` che la nostra query GraphQL si aspetta. Il secondo argomento passato a `field` indica a GraphQL che il tipo sarà un array di oggetti di tipo `RepoType`. Il parametro `null: false` indica che `repos` non sarà mai nullo; nel peggiore dei casi, sarà invece un array vuoto.

Il metodo `repos` è il resolver per questo campo. Quando il campo `repos` viene chiamato tramite un'operazione GraphQL, la libreria GraphQL utilizzerà il metodo `repos` per risolvere i dati che saranno visualizzati per quel campo. Se non richiedessimo il campo  `repos`, il metodo non verrebbe mai chiamato.

Questa configurazione in `QueryType` è per la maggior parte completa. Tuttavia, abbiamo fatto riferimento a una costante `RepoType`, ma non l'abbiamo ancora definita. Questa costante definirà i campi accessibili per gli oggetti `Repo` tramite l'API GraphQL. Ecco come definiremo quel tipo:

`app/graphql/repo_type.rb`

```ruby
module Types
    class RepoType < Types::BaseObject
        field :name, String, null: false
        field :url, String, null: false
    end
end
```

In questo tipo, definiamo due campi di tipo String, `name` e `url`, e entrambi i campi non restituiranno mai valori nulli. Non è necessario definire metodi resolver per questi campi, perché gli oggetti rappresentati da questo tipo hanno già i metodi `name` e `url`. La libreria `GraphQL` utilizzerà quei metodi.

Ora questo sarà sufficiente per far superare il nostro test. Eseguiamolo e scopriamolo con bundle exec rspec spec/requests/graphql/queries/repos_spec.rb:

```sh
1 example, 0 failures
```

Riassumiamo cosa abbiamo fatto.

Per aggiungere un nuovo campo alla nostra API GraphQL per leggere un elenco di tutti i repository, abbiamo utilizzato il metodo `field` all'interno della classe QueryType.

Quando aggiungiamo un nuovo campo a `QueryType`, dobbiamo definire come quel campo viene risolto dall'API GraphQL. Per farlo, abbiamo aggiunto un metodo con lo stesso nome del campo alla classe `QueryType`: `repos`. Per questo esempio, il nostro metodo `repos` ha utilizzato `Repo.all`, che ha restituito un array di oggetti del modello `Repo`.

Per lavorare con questi oggetti Repo nell'API GraphQL, abbiamo dovuto definire un'altra classe chiamata `RepoType`. Questa classe definisce come questi oggetti del modello Repo sono rappresentati in GraphQL. In questa classe abbiamo definito due campi: `name` e `url`.

È importante sottolineare che non è necessario definire metodi risolutivi per questi campi, poiché gli oggetti `Repo` che `RepoType` rappresenta rispondono già ai metodi `name` e `url`, e quindi la classe `RepoType` utilizzerà quei metodi dalla classe di modello `Repo`.

Con tutto ciò, ora siamo in grado di ottenere un elenco di repository visualizzati nella nostra API. 

#### Mostrare un singolo repository
In un'applicazione Rails tradizionale, per mostrare informazioni su una risorsa specifica, si definirebbe una route come:

```sh
GET /repos/:id
```

In GraphQL, possiamo creare una query e passarle anche una variabile. Il modo in cui lo scriviamo nella sintassi GraphQL è:

```ruby
query ($id: ID!) {
    repo(id: $id) {
        name
        url
    }
}
```

La prima riga della nostra query ora definisce una variabile (indicata dal simbolo del dollaro) e il suo tipo correlato: `ID!`. 
Questo tipo accetta qualsiasi `ID` di record che gli passiamo, anche se l'`ID` fosse una stringa o un numero. Il punto esclamativo alla fine di questo tipo è il modo in cui GraphQL indica `non nullo`. 
Mettendo tutto insieme: c'è una variabile chiamata `$id` che accetta un valore di tipo ID, e quel valore può essere una stringa o un numero, ma mai nullo.

Nella seconda riga della query, recuperiamo il campo `repo` e passiamo la variabile `$id` come argomento al campo per indicare quale `repo` vogliamo recuperare. 

Ora che abbiamo esaminato come scrivere questa query GraphQL in teoria, scriviamo un `test` e il codice associato per renderlo realtà. 

Creeremo un nuovo file in `spec/requests/graphql/queries/repo_spec.rb` e vi inseriremo questo codice:

```ruby
require 'rails_helper'

RSpec.describe "Graphql, repo query" do
  let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }

  it "retrieves a single repo" do
    query = <<~QUERY
    query($id: ID!) {
      repo(id: $id) {
        name
        url
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: {id: repo.id} }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "repo" => 
        {
          "name" => repo.name,
          "url" => repo.url,
        }
    )
  end
end

```

Adesso eseguiamo il test con `bundle exec rspec spec/requests/graphql/queries/repo_spec.rb`

```sh
Failure/Error: expect(response.parsed_body).not_to have_errors

       Expected there to be no errors, but there were:
       [
         {
           "message": "Field 'repo' doesn't exist on type 'Query'",
           "locations": [
             {
               "line": 2,
               "column": 3
             }
           ],
           "path": [
             "query",
             "repo"
           ],
           "extensions": {
             "code": "undefinedField",
             "typeName": "Query",
             "fieldName": "repo"
           }
         },
         {
           "message": "Variable $id is declared by anonymous query but not used",
           "locations": [
             {
               "line": 1,
               "column": 1
             }
           ],
           "path": [
             "query"
           ],
           "extensions": {
             "code": "variableNotUsed",
             "variableName": "id"
           }
         }
       ]

```

Il test ritorna come errore che non esiste il campo `repo`.

Dobbiamo aggiungere un campo a `QueryType`. Andiamo in `app/graphql/query_type.rb` e aggiungiamolo. Quando abbiamo aggiunto il campo `repos` in precedenza, abbiamo utilizzato il metodo `field`. Useremo nuovamente lo stesso metodo, ma questa volta con una leggera differenza:

`app/graphql/query_type.rb`

```ruby
#....

field :repo, RepoType, null: false do
    argument :id, ID, required: true
end

#...
```

Stavolta gli passiamo un blocco! Il blocco definisce un argomento per il campo, specificando il suo tipo (`ID`) e che l'argomento è obbligatorio per poter risolvere il campo(`required: true`). Per definire il risolutore per questo campo, aggiungeremo un nuovo metodo chiamato `repo` direttamente sotto questa definizione di campo:

```ruby
def repo(id:)
    Repo.find(id)
end
```

Questo metodo accoglie l'argomento `id` dal campo e lo utilizza per risolvere un oggetto che GraphQL utilizzerà. Tale oggetto è una singola istanza di `Repo`. La nostra API GraphQL utilizzerà in questo caso l'oggetto `Repo` e lo rappresenterà attraverso la classe `RepoType` che abbiamo definito in precedenza, poiché questo è il tipo che abbiamo definito per il nuovo campo `repo`.

Quando eseguiamo nuovamente il test, sarà tutto ok.

Ora abbiamo un modo per mostrare informazioni su un singolo repository tramite la nostra API GraphQL. Per realizzare questo, consentiamo l'accesso a un campo `repo` attraverso questa query:

```ruby
query ($id: ID!) {
    repo(id: $id) {
        name
        url
    }
}
```


Questa query è definita per accettare una variabile chiamata `$id`, che passiamo successivamente come argomento al campo `repo`. La nostra API prende quindi questo argomento `id` e lo utilizza nel metodo risolutore in `QueryType` per trovare un oggetto `Repo`, che viene poi rappresentato nella nostra API attraverso i campi definiti nella classe `RepoType`.

Abbiamo accennato in modo sommario al funzionamento della classe `RepoType`. Ciò è stato fatto in modo che ci abituassimo a come definire campi e come far sì che questi campi accettino argomenti. 
Ora che abbiamo compreso questa parte fondamentale di GraphQL, parliamo un po' di come GraphQL sa come utilizzare gli attributi `name` e `url` degli oggetti `Repo`. Affronteremo questo processo aggiungendo un altro campo.

#### Aggiunta di un campo personalizzato

Ora aggiungeremo un campo personalizzato a `RepoType`. Questo campo si chiamerà `nameReversed` e restituirà il nome di un repository, ma invertito. Ciò significa che `Repo Hero` verrà restituito come `oreH opeR` come valore del campo. 

Per aggiungere un campo personalizzato a `RepoType`, dobbiamo utilizzare nuovamente il metodo `field`:
```ruby
module Types
    class RepoType < Types::BaseObject
        field :name, String, null: false
        field :url, String, null: false
        field :name_reversed, String, null: false
    end
end
```
Per accedere a questo campo, aggiorneremo il nostro `repo_spec.rb` per recuperare questo campo:

`spec/requests/graphql/queries/repo_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Graphql, repo query" do
  let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }

  it "retrieves a single repo" do
    query = <<~QUERY
    query($id: ID!) {
      repo(id: $id) {
        name
        nameReversed ①
        url
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: {id: repo.id} }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "repo" => 
        {
          "name" => repo.name,
          "nameReversed" => repo.name.reverse, ②
          "url" => repo.url,
        }
    )
  end
end

```

① Aggiungere il campo "nameReversed" alla query.
② Verificare che il valore ritorni nella risposta.

Con queste modifiche apportate sia a RepoType che al test, vediamo cosa succede quando eseguiamo il nostro test con `bundle exec rspec spec/requests/graphql/queries/repo_spec.rb`

```sh
 RuntimeError:
    Failed to implement Repo.nameReversed, tried:

    - `Types::RepoType#name_reversed`, which did not exist
    - `Repo#name_reversed`, which did not exist
    - Looking up hash key `:name_reversed` or `"name_reversed"` on `#<Repo:0x0000000115682f98>`, but it wasn't a Hash

    To implement this field, define one of the methods above (and check for typos), or supply a `fallback_value`.
```

C'è un errore! Questo errore è accompagnato da molte spiegazioni direttamente nel messaggio di errore. Afferma che quando GraphQL cerca di risolvere il campo `name_reversed`, effettua le seguenti operazioni nell'ordine:

* Controlla se esiste un metodo di istanza `name_reversed` in Types::RepoType.
* Controlla se esiste un metodo di istanza `name_reversed` nell'oggetto utilizzato per questo campo, cioè un'istanza di Repo.
* Verifica se l'istanza di Repo funziona come un dizionario (Hash), cercando di accedere a una chiave "name_reversed" o 'name_reversed' su quell'oggetto.

Poiché nessuna di queste opzioni esiste, otteniamo questo errore.
Possiamo risolvere questo errore aggiungendo un metodo a `Types::RepoType` per gestirlo. Il nostro primo istinto potrebbe essere quello di aggiungere questo metodo:

`app/graphql/types/repo_type.rb`

```ruby
def name_reversed
    name.reverse
end 
```

Poiché `RepoType` ha già un campo chiamato `name`, sembra logico che dovremmo essere in grado di accedervi chiamando questo metodo anche qui.

Questo non funzionerà:

```sh
NameError:
       undefined local variable or method `name' for #<Types::RepoType
```

L'oggetto RepoType, sebbene abbia un campo chiamato `name`, non ha un metodo corrispondente chiamato `name`. Per risolvere i valori dei campi, GraphQL utilizza un altro metodo chiamato `object`. Possiamo usarlo nel nostro metodo `name_reversed` per ottenere il comportamento desiderato:

`app/graphql/types/repo_type.rb`

```ruby
def name_reversed
    object.name.reverse
end
```

Il metodo `object` ci consente di accedere all'oggetto che `RepoType` sta risolvendo. Quindi, quando utilizziamo `RepoType` per risolvere il campo `repos` o `repo` nella nostra API GraphQL, l'oggetto che viene risolto è un'istanza della classe modello Repo.

Utilizzando il metodo `object` qui per accedere al metodo `Repo#name`, possiamo far sì che il nostro campo faccia ciò che il nostro test si aspetta che faccia.

Se ora eseguiamo il nostro test, vedremo che ora sta passando.

```sh
bundle exec rspec spec/requests/graphql/queries/repo_spec.rb
```
Ed ecco fatto! Abbiamo aggiunto un campo personalizzato a RepoType per restituire il nome invertito. Questa parte ha dimostrato come possiamo utilizzare il metodo `object` per accedere all'oggetto sottostante che viene utilizzato per risolvere i campi di RepoType. Questo è particolarmente utile quando desideriamo preformattare o modificare valori dagli attributi di un oggetto prima che vengano presentati tramite la nostra API GraphQL.
