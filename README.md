### Cos'è GraphQL?
GraphQL è un linguaggio di query che assomiglia molto a JSON, ma con solo le chiavi e nessun valore:

```ruby
query {
    book(id: 1) {
    title
    }
}
```

È stato inventato nei laboratori Facebook, ma si è diffuso rapidamente su molte altre aziende in tutto il mondo.

L’approccio di GraphQL è quello di prendere l’idea di un’API e capovolgerla. Dove un L'API normalmente definisce la propria struttura per un endpoint, GraphQL funziona così che il cliente definisca la struttura dei dati che desidera. In un'API REST, puoi avere un endpoint come `/books/1`, che restituirà tutti questi dati:

```sh
{
    "book": {
        "title": "GraphQL for Rails Developers",
        "author": "Ryan Bigg",
        "pages": 200,
    }
}
```
Ma in GraphQL, un client può definire una query per recuperare solo le parti di dati che desidera. Utilizzando nuovamente l'esempio sopra:

```graphQL
query {
    book(id: 1) {
        title
    }
}   
```

Questa sintassi indica all'API GraphQL che desideriamo ottenere un libro con un ID di 1 e che vogliamo solo il titolo di quel libro. Quando eseguiamo questa query sulla nostra API GraphQL, otterremo solo i dati che abbiamo richiesto.

```sh
{
    "book": {
        "title": "GraphQL For Rails Developers",
    }
}
```

Per fare un altro esempio, per richiedere un libro e i suoi capitoli utilizzando una tradizionale API REST, di solito sarebbero coinvolte due richieste: una per ottenere il libro e un'altra per ottenere i suoi capitoli:

```ruby 
GET /books/1
GET /books/1/chapters
```
In GraphQL, questa è una singola richiesta:

``` graphQL
query {
    book(id: 1) {
        title
        chapters {
            title
        }
    }
}
```

Questa query restituirebbe le informazioni sul libro che abbiamo richiesto, insieme alle informazioni sui capitoli:
```sh
{
    "book": {
        "title": "GraphQL For Rails Developers",
        "chapters": [
            {
                "title": "About this book"
            }
        ]
    }
}
```

Questa è la parte "graph" di GraphQL: possiamo accedere a molte informazioni e quindi accedere a dati correlati da quel punto nel "grafo".

Inoltre, GraphQL delinea chiaramente le operazioni che recuperano dati da quelle che modificano dati. Le operazioni che recuperano dati sono chiamate query, e abbiamo appena visto un esempio di esse. 

Le operazioni che modificano dati sono chiamate mutation e iniziano con la parola "mutation":

```graphQL
mutation {
    createBook(title: "GraphQL For Rails Developers") {
        id
    }
} 
```
Questa mutazione creerebbe un libro con il titolo "GraphQL per Sviluppatori Rails" e restituirebbe l'ID di quel libro.

### Perché GraphQL?
Ora che abbiamo visto un esempio di cosa sia GraphQL, diamo uno sguardo al motivo.

#### Puoi scegliere i dati a tua discrezione
 Quando scriviamo un'operazione GraphQL per interrogare alcuni dati, scriviamo quella query in una sintassi che assomiglia al JSON:

 ```GraphQL
 query {
    book {
        title
    }
}
 ```

 Quando inviamo questa query al nostro server, esso determinerà i dati corretti da restituire. In questo esempio, i dati che possiamo aspettarci di ricevere saranno:

 ```sh 
 {
    "book": {
        "title": "GraphQL For Rails Developersr"
    }
}
 ```

I dati restituiti sono esclusivamente quelli che abbiamo richiesto: un libro e il suo titolo. GraphQL ci consente di richiedere solo i dati che ci interessano effettivamente, anziché il server presenti una vasta gamma di dati che potrebbero interessarci.

Se volessimo richiedere ulteriori dati, come ad esempio l'autore e l'anno di pubblicazione, possiamo aggiungere altre due righe alla nostra query per quei dati:

```GraphQL
query {
    book {
        title
        author
        publicationYear
    }
}   
```
E ora riceveremo quei dati:

```sh
{
    "book": {
    "title": "GraphQL For Rails Developers",
    "author": "Ryan Bigg",
    "publicationYear": 2023 
    }
}

```

#### Tutto ha un tipo
Quando utilizziamo un'API GraphQL, ogni pezzo di dati restituito da quell'API ha un tipo definito. Riutilizzando il nostro esempio di prima, i tipi sono i seguenti:

```GraphQL
{
    "book": { ①
        "title": "GraphQL For Rails Developers", ②
        "author": "Ryan Bigg", ③
        "publicationYear": 2023 ④
    }
}
```
* ① Book
* ② String
* ③ String
* ④ Int

Quando conosciamo il tipo di dati con cui stiamo lavorando, possiamo aspettarci che si comporti in modi prevedibili. Un esempio che mi piace usare qui è un campo chiamato "amount" (importo). È una quantità? Un importo in dollari? Se si tratta di un importo in dollari, è formattato come "$12.34"?

Un campo di importo restituito da un'API GraphQL avrebbe un tipo chiaro e da questo potremmo capire come utilizzare quel campo.


#### Capitolo 1

* [Iniziamo con Rails e GraphQl](/public/documentation/chapter1/getting_started_with_graphql.md)

