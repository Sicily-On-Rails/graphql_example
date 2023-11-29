## Lavorare con le associazioni
Abbiamo aggiunto il modello 'Repo' alla nostra applicazione e aggiunto alcuni campi al nostro schema GraphQL in modo da poter interrogare tali repository. In questo capitolo, aggiungeremo un altro modello chiamato 'Category' e lo useremo per raggruppare i repository in categorie distinte. Alla fine di questo capitolo, saremo in grado di utilizzare l'API GraphQL per richiedere le categorie di un repository, così come i repository di una categoria. Ecco un esempio dell'ultima interrogazione che saremo in grado di eseguire:

```ruby
query findCategory($id: ID!) {
    category(id: $id) {
    name
        repos {
            name
            url
        }
    }
}
```

Questo capitolo si concluderà affrontando una delle critiche più importanti rivolte a GraphQL: la capacità di GraphQL di nidificare i campi all'infinito. Affronteremo questo problema utilizzando un'impostazione chiamata max_depth per limitare la profondità massima delle query GraphQL nella nostra applicazione. Iniziamo questo capitolo creando un modello di categoria.


#### Creare un modello "categoria"

Prima di tutto, creiamo il modello `category`:

```sh
rails g model category name:string
```

Questo modello rappresenterà le categorie stesse, ma avremo bisogno di un altro modello per rappresentare i collegamenti tra categorie e repository. Poiché le categorie possono avere molti repository e i repository possono appartenere a molte categorie, dobbiamo creare una tabella di collegamento per unire categorie e repository. Per rappresentare tale tabella di collegamento, aggiungeremo un altro modello chiamato `CategorizedRepo`.

```sh
rails g model categorized_repo category:references repo:references
```

Ora eseguiamo le migrazioni per queste tabelle:

```sh
rails db:migrate
```

Prima di procedere, aggiungiamo le associazioni ai modelli per completarne la configurazione. Inizieremo con il modello Repo
`app/models/repo.rb`:

```ruby
class Repo < ApplicationRecord
    has_many :categorized_repos
    has_many :categories, through: :categorized_repos
end

```

E faremo lo stesso, ma in modo opposto, nel modello Category:

`app/models/category.rb`

```ruby
class Category < ApplicationRecord
    has_many :categorized_repos
    has_many :repos, through: :categorized_repos
end

```

Ora che abbiamo configurato tipicamente Rails per questi modelli, vediamo cosa ci vorrà per visualizzare questi record attraverso GraphQL.

#### Recuperare una singola categoria utilizzando GraphQL

Stiamo per aggiungere un campo di categoria al nostro schema GraphQL in modo da poter raccogliere informazioni su una categoria. Per garantire che questo campo funzioni ora e in futuro, scriveremo prima un test. 

`spec/requests/graphql/queries/category_spec.rb:`

```ruby
require 'rails_helper'

RSpec.describe "Graphql, category query" do
  let!(:category) { Category.create!(name: "Ruby") }
  

  it "retrieves a single category" do
    query = <<~QUERY
    query($id: ID!) {
      category(id: $id) {
        name
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: {id: category.id} }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "category" => 
        {
          "name" => category.name,
          
        }
    )
  end
end

```

Questo è quasi una copia diretta del nostro test per la query di repo, infatti lo è! Ma abbiamo cambiato il nome qui da "repo" a "category".

Quando eseguiamo questo test con `bundle exec rspec`, avremo degli errori, perchè il campo `category` non esiste.

Per risolvere questo problema, dovremo aggiungere un altro campo al file che definisce i campi `Query`, e questo è il file `query_type.rb`.

`app/graphql/types/query_type.rb`

```ruby
#....

    field :category, CategoryType, null: false do 
        argument :id, ID, required: true
    end

    def category(id: )
        Category.find(id)
    end

#...

```

Questo codice definisce il campo di categoria di cui abbiamo bisogno qui. Quando si risolve questo campo, verrà utilizzata una classe ancora non definita chiamata CategoryType. Il modo in cui viene risolto questo campo è lo stesso del campo repo: cercando per ID.
Potremmo far risolvere questo campo nel modo che preferiamo. Forse per le categorie vorremmo utilizzare i nomi invece degli ID. Ecco come cambieremmo questo campo se volessimo farlo:

```ruby
def category(name:)
    Category.find_by!(name: name)
end
```
Per il momento resteremo con l'ID.
Ora passiamo a `CategoryType`. Come possiamo vedere dal nostro test, il nostro `CategoryType` dovrà avere un campo di `name` definito in esso, e nient'altro (per ora!). Definiamo ora quel tipo.

`app/graphql/types/category_type.rb`

```ruby
module Types
    class CategoryType < Types::BaseObject
        field :name, String, null: false
    end
end

```

Questo è un tipo molto semplice per ora. Questa classe definisce il comportamento degli oggetti risolti con la classe CategoryType, e tale comportamento è che tali oggetti possono avere un campo di nome richiesto. Fortunatamente, è esattamente ciò che stiamo cercando nel nostro test al momento.

#### Risoluzione dei repository per una categoria

Quando lavoriamo con le associazioni in Rails, possiamo chiamare un metodo per accedere all'associazione. Il modo di accedere alle associazioni in GraphQL non è molto diverso. Per accedere ai repository associati alle categorie, scriviamo questa query:

```ruby
query ($id: ID!) {
    category(id: $id) {
        name
        repos {
            name
        }
    }
}
```

Questa query dice a GraphQL che vogliamo prima risolvere un campo di categoria e, successivamente, per l'oggetto restituito, vogliamo risolvere il campo dei repository.
Aggiorniamo il test che abbiamo appena scritto per utilizzare la nuova struttura di questa query:

`spec/requests/graphql/queries/category_spec.rb:`

```ruby
require 'rails_helper'

RSpec.describe "Graphql, category query" do
  let!(:category) { Category.create!(name: "Ruby") }
  let!(:repo) do
    Repo.create!(name: "Grapql example", url: "https://github.com", categories: [category]) 
  end

  it "retrieves a single category" do
    query = <<~QUERY
    query($id: ID!) {
      category(id: $id) {
        name
        repos{
          name
          url
        }
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: {id: category.id} }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "category" => 
        {
          "name" => category.name,
          "repos" => [
            {
              "name" => repo.name,
              "url" => repo.url,
            }
          ]
        }
    )
  end
end

```

L'aspettativa alla fine del nostro test qui afferma ora che stiamo ricevendo un array di repository con un solo elemento in quell'array. Quell'elemento dovrebbe essere l'unico repository che abbiamo creato e collegato a questa categoria.
Quando eseguiamo questo test(`bundle exec rspec`), vedremo che fallisce. Questo perché non abbiamo ancora definito il campo dei `repos` sulla classe `CategoryType`. Facciamolo ora.

`app/graphql/types/category_type.rb`

```ruby
module Types
    class CategoryType < Types::BaseObject
        field :name, String, null: false
        field :repos, [Types::RepoType], null: false
    end
end
```

Questo codice definisce il campo dei `repos` nella classe `CategoryType`. Questo campo restituirà un array di oggetti `RepoType`, utilizzando la classe `RepoType` esistente che abbiamo già definito. Indichiamo che questo campo restituirà un array di repos rendendo il tipo un array di RepoType.

Quando eseguiamo nuovamente il test, vedremo che ora è passato.

Fatto! Avendo definito una classe `RepoType`, aggiungere un campo per recuperare l'elenco dei repository di una categoria è stato molto facile. Questo campo funziona utilizzando il metodo `repos` sull'oggetto `Category` che viene risolto dal nostro `CategoryType`.
In effetti, il codice sta facendo esattamente ciò che faremmo in un'applicazione Rails: chiamare un metodo come `category.repos` per recuperare tutti i repository di una categoria. Il punto principale di differenza qui è che i `repository` per la categoria vengono recuperati solo quando li chiediamo.

#### Risoluzione delle categorie per un repository

Ora che abbiamo la possibilità di recuperare i repository di una categoria, adesso aggiungiamo la capacità di recuperare le categorie di un repository. Una query GraphQL per recuperare le categorie di un repository assomiglierebbe a questa:

```ruby
query findRepoCategories($id: ID!) {
    repo(id: $id) {
        name
        categories {
            name
        }
    }
}
```
Questa query dice a GraphQL che vogliamo prima risolvere un campo di repo e, successivamente, per l'oggetto restituito, vogliamo risolvere il campo delle categorie. È lo stesso di quanto abbiamo appena fatto, ma al contrario.

Scriviamo un nuovo test per questo:

`spec/requests/graphql/queries/repo_categories_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Graphql, repo query, with categories" do
  let!(:repo) { Repo.create!(name: "Repo Hero", url: "https://github.com/repohero/repohero") }
  let!(:category) { Category.create!(name: "Ruby") }

  before do
    repo.categories << category
  end

  it "retrieves a single repo, with its categories" do
    query = <<~QUERY
    query findRepoCategories($id: ID!) {
      repo(id: $id) {
        ...on Repo {
          name
          categories {
            name
          }
        }
      }
    }
    QUERY

    post "/graphql", params: { query: query, variables: { id: repo.id } }
    expect(response.parsed_body).not_to have_errors
    expect(response.parsed_body["data"]).to eq(
      "repo" => {
        "name" => repo.name,
        "categories" => [
          {
            "name" => category.name,
          }
        ]
      }
    )
  end
end

```

Questo assomiglia al test che abbiamo appena scritto nella sezione precedente! È effettivamente molto simile. I nomi sono semplicemente invertiti. Dove avevamo repos, ora abbiamo categories. E dove abbiamo categories, abbiamo repos. Stiamo facendo questo in modo che possiamo garantire che non importa quale "lato" venga richiesto, possiamo sempre risolvere l'altro "lato" associato. Vogliamo essere in grado di interrogare sia per le categorie di un repository che per i repository di una categoria.

Quando eseguiamo(`bundle exec rspec`) questo test, vedremo che fallisce.


Questo perché non abbiamo ancora definito il campo delle categorie sulla classe RepoType. Facciamolo ora.

`app/graphql/types/repo_type.rb`

```ruby
module Types 
    class RepoType < Types::BaseObject
        field :id, ID, Integer, null: false
        field :name, String, null: false
        field :url, String, null: false
        field :name_reversed, String, null: false
        field :categories, [Types::CategoryType], null: false
        
        def name_reversed
            object.name.reverse
        end

    end
    
end

```

Ora stiamo utilizzando CategoryType qui per restituire un array di categorie, allo stesso modo in cui abbiamo usato RepoType per restituire un array di repository.
Quando eseguiamo nuovamente il test, vedremo che ora è passato.

Ora abbiamo il modo per recuperare le categorie di un repository e un modo per recuperare i repository di una categoria. Ora possiamo scrivere una query come questa:

```ruby
query findCategoryRepos($id: ID!) {
    category(id: $id) {
        name
        repos {
            name
        }
    }
}

```

O come questa:

```ruby
query findRepoCategories($id: ID!) {
    repo(id: $id) {
        name
        categories {
            name
        }
    }
}   
```

E otterremo i dati che abbiamo richiesto. Ma GraphQL ci consente di nidificare quanto vogliamo, quindi potremmo anche scrivere una query come questa:

```ruby
query ($id: ID!) {
            repo(id: $id) {
                name
                categories {
                    name
                    repos {
                        name
                        categories {
                            name
                            repos {
                                name
                                categories {
                                    name        
                                ...
                        }
                    }
                }
            }
        }
    }
}

```
