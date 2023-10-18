In questo breve primo capitolo, creeremo una nuova app Rails e aggiungeremo la gemma GraphQL. Successivamente, eseguiremo il generatore incorporato della gemma GraphQL e configureremo un modello di Active Record in modo da avere qualcosa da utilizzare nella nostra API GraphQL.

### Creare una nuova applicazione Rails.

L'applicazione su cui lavoreremo durante questo libro si chiama "Repo Hero". Sarà un aggregatore di recensioni per i repository Git. Gli utenti saranno in grado di aggiungere i loro repository preferiti, categorizzarli e lasciare recensioni per quei repository. Alla fine di questo libro, tutto ciò sarà reso possibile attraverso la nostra API GraphQL.

Per iniziare, ci assicureremo di avere installata la versione corretta di Rails:

```sh 
gem install rails -v 7.0.8
```

E quindi possiamo generare questa nuova applicazione:

```sh 
rails _7.0.8_ new --api --minimal repo_hero
```

Le opzioni `--api` e `--minimal` passate a Rails in questo modo renderanno l'applicazione il più piccola possibile, includendo solo le parti che desideriamo e niente che non desideriamo.

### Aggiungere RSpec

Per testare questa applicazione e tutte le sue funzionalità, utilizzeremo RSpec. Lo stiamo configurando qui in modo che quando eseguiamo i generatori più avanti, verranno generati con file RSpec anziché file Test::Unit.

Per configurare RSpec, eseguiremo il seguente comando:

```sh 
bundle add rspec-rails --group "development, test"
```

Una volta completato questo comando, ora eseguiremo l'installatore di RSpec:
```sh 
rails g rspec:install
```

Questo aggiungerà i file di base di RSpec alla nostra applicazione.

### Aggiunta della gemma GraphQL.

La gemma graphql è la gemma per la creazione di API GraphQL all'interno delle applicazioni Ruby. È utilizzata da aziende come Shopify e GitHub.

```sh 
bundle add graphql
```

Una volta installata quella gemma, possiamo eseguire un generatore di Rails fornito dalla gemma stessa. Questo generatore configurerà la struttura GraphQL di cui la nostra applicazione ha bisogno:

```sh
rails g graphql:install
```

Questo generatore genera diversi file differenti.

Vedremo a tempo debito cosa fanno la maggior parte di questi file. Per ora, li stiamo configurando in modo da potervi accedere in seguito.

La cosa principale a cui dovremmo prestare attenzione qui è che è stata aggiunta una route a `config/routes.rb:`

```ruby
post "/graphql", to: "graphql#execute"
```

Questa `route` imposta il nostro punto di ingresso GraphQL. Ogni volta che eseguiamo un'operazione GraphQL, stiamo effettuando una richiesta `POST` a `/graphql`. 
GraphQL utilizza una richiesta `POST` in modo da supportare lunghe richieste, cosa che una richiesta `GET` non fa. Questo è diverso da come potresti capire il routing delle richieste all'interno di un'applicazione Rails, dove le operazioni di lettura sono tipicamente richieste `GET` e le operazioni di scrittura sono tipicamente richieste `POST, PUT, PATCH o DELETE`.
Questo è un aspetto peculiare del lavoro con GraphQL e rappresenta una notevole differenza rispetto a ciò che ci si aspetterebbe da chi è familiare con le `REST API`, ma alla fine non è né positivo né negativo. 
GraphQL ha modi per differenziare tra operazioni di lettura e scrittura senza utilizzare i metodi HTTP, e vedremo come funziona in seguito.

Questo punto di ingresso punta a un controller chiamato `GraphqlController` e a un'azione all'interno di quel controller chiamata `execute`. Diamo un'occhiata a quell'azione ora:

`app/controllers/graphql_controller.rb`

```ruby
def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
        # Query context goes here, for example:
        # current_user: current_user,   
    }

    result = RepoHeroSchema.execute(query, variables: variables, context:
    context, operation_name: operation_name)
    render json: result
    rescue StandardError => e
        raise e unless Rails.env.development?
    handle_error_in_development(e)
end
```

Questa azione riceve alcuni parametri dalla richiesta e li passa a una classe chiamata `RepoHeroSchema` e al suo metodo `execute`. 
Questo metodo funge da punto di ingresso nel mondo di GraphQL per la nostra applicazione. 
La chiamata a questo schema non deve avvenire all'interno di un controller, e per dimostrarlo adesso interromperemo questa guida per mostrare come possiamo eseguire operazioni GraphQL utilizzando RepoHeroSchema, al di fuori del contesto di un controller.

### Utilizziamo il nostro schema GraphQL.

Per utilizzare il nostro schema GraphQL, scriveremo un script . Solo per assicurarci davvero che possiamo usare questa cosa al di fuori del contesto di un controller. Possiamo creare uno script chiamato `graphql-test.rb` nella radice della nostra applicazione Rails.

```ruby
    operation = <<~GQL
        query { ①
        testField ②
    }
    GQL
result = RepoHeroSchema.execute(operation)
puts JSON.pretty_generate(result)
```

* ① Definizione del tipo dell'operazione GraphQL: l'operazione è un'operazione di tipo query.

* ② Il campo che vogliamo recuperare.

Le operazioni GraphQL sono tutte basate sui campi.

Quando utilizziamo un campo in un'operazione GraphQL, stiamo dicendo all'API che desideriamo tutti i dati definiti per quel campo. 

Questo script definisce l'operazione GraphQL e la eseguirà sullo schema fornito. 
Non abbiamo bisogno della complessità aggiuntiva presente nel controller, come le variabili, il contesto o persino un nome per l'operazione, abbiamo solo bisogno della query. 

Eseguiamo questo script ora. Avremo bisogno di caricare `RepoHeroSchema`, e per questo motivo eseguiremo questo script non utilizzando l'eseguibile ruby, ma invece con `rails runner`:

```ruby
rails runner graphql-test.rb
```

Quando eseguiamo lo script, questo è l'output che vedremo:

```sh
{
    "data": {
        "testField": "Hello World!" 
    }
}
```

La nostra API GraphQL ci ha restituito la nostra prima risposta. Abbiamo richiesto un campo chiamato testField e ci ha restituito i dati contenuti in quel campo, attualmente definiti come la stringa `"Hello World!"`.


Ma come ha fatto la nostra API a sapere di restituire quel valore per quel campo? 

Per ottenere una risposta a questa domanda, dovremo esaminare la classe `RepoHeroSchema` e vedere come si integra.

### Come si integra lo schema.

Un'API GraphQL è costruita intorno a uno schema, e uno schema definisce il comportamento dell'API. Esaminiamo lo schema che è stato definito per la nostra API GraphQL tramite il generatore che abbiamo eseguito in precedenza.

`app/graphql/repo_hero_schema.rb`

```ruby
class RepoHeroSchema < GraphQL::Schema
    mutation(Types::MutationType)
    query(Types::QueryType)
...
end

```

I due principali tipi di operazioni, mutazioni e query, sono definiti all'interno dei propri file di tipo. 
Per fare un ripasso: le mutazioni sono le operazioni che utilizziamo quando creiamo, aggiorniamo o eliminiamo dati.

Se stiamo leggendo dati, useremmo invece le `query`. 

Torneremo alle mutazioni, ma per ora esamineremo il `QueryType`.

`app/graphql/query_type.rb`

```ruby
module Types
    class QueryType < Types::BaseObject
        ...
        # TODO: remove me
        field :test_field, String, null: false,
            description: "An example field added by the generator"
        def test_field
            "Hello World!"
        end
    end
end
```

Il `QueryType` all'interno della nostra applicazione definisce un campo e la sua risposta utilizzando il metodo field e definendo un metodo che corrisponde al nome del campo.

Ma questo è chiamato `test_field`, e il campo che stavamo richiedendo era chiamato testField. Quindi, perché la differenza? 
La convenzione è la ragione. 

`GraphQL` corrisponde alle convenzioni di JavaScript, e le convenzioni di JavaScript favoriscono i nomi in `camelCase` rispetto a quelli in snake_case.

Tuttavia, stiamo scrivendo codice Ruby in `QueryType`, e quindi si applica la convenzione Ruby e usiamo `test_field` invece.
Quando si tratta di codice Ruby, useremo le convenzioni Ruby. 

La gemma GraphQL convertirà queste convenzioni in convenzioni JavaScript quando appropriato.

Dopo il nome del campo nel metodo `field` ci sono diversi altri argomenti utili.

Il secondo argomento definisce il tipo del valore restituito dal campo: una stringa (`String`).

Il parametro `null: false` dichiara che il valore restituito da questo campo non sarà mai nullo, e quindi i consumatori di questa API non dovranno effettuare alcun tipo di controllo per i valori null su questo campo.

Infine, l'opzione `description` contiene la documentazione che comparirà accanto a questo campo in GraphiQL o in qualsiasi altro visualizzatore di documentazione GraphQL. 

Se cambieremo il valore restituito da questo metodo, vedremo quei cambiamenti riflessi immediatamente, proprio come ci aspettiamo in qualsiasi altra parte del codice della nostra applicazione Rails. 
Proviamo ora a farlo cambiando il metodo `test_field`:

`app/graphql/query_type.rb`

```ruby
def test_field
    "Hello GraphQL!"
end 
```

Eseguiamo nuovamente

```ruby
    rails runner graphql-test.rb
```


Mostrerà che l'output è cambiato:

```sh
{
    "data": {
    "testField": "Hello GraphQL!"
}
}
```

Ora abbiamo compreso come utilizzare la nostra API GraphQL, sebbene attraverso uno script e non attraverso il tradizionale percorso delle richieste. Ora che abbiamo visto come utilizzare GraphQL da solo, integriamolo con qualcosa che conosciamo da un'applicazione Rails: un modello.