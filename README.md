# Watch the Screencast
[![Autocomplete in Rails 5](https://d2d8g20jj5tev4.cloudfront.net/rubyplus-screencast.png)](https://rubyplus.com/episodes/51-Autocomplete-in-Rails-5)

Autocomplete using Typeahead and Searchkick in Rails 5

## Setup SearchKick

Create a new Rails 5 project and add searchkick gem to Gemfile.

```
gem 'searchkick'
```

Run bundle. Create an article resource.

```
rails g scaffold article title content:text
```

Add searchkick to the article model.

```ruby
class Article < ApplicationRecord
  searchkick
end
```

## Setup Database

Add sample data to seeds.rb.

```ruby
Article.destroy_all
data = [{ title: 'Star Wars', content: 'Wonderful adventure in the space' }, 
        { title: 'Lord of the Rings', content: 'Lord that became a ring' },
        { title: 'Man of the Rings', content: 'Lord that became a ring' },
        { title: 'Woman of the Rings', content: 'Lord that became a ring' },
        { title: 'Dog of the Rings', content: 'Lord that became a ring' },
        { title: 'Daddy of the Rings', content: 'Lord that became a ring' },
        { title: 'Mommy of the Rings', content: 'Lord that became a ring' },
        { title: 'Duck of the Rings', content: 'Lord that became a ring' },
        { title: 'Drug Lord of the Rings', content: 'Lord that became a ring' },
        { title: 'Native of the Rings', content: 'Lord that became a ring' },
        { title: 'Naysayer of the Rings', content: 'Lord that became a ring' },
        { title: 'Tab Wars', content: 'Lord that became a ring' },
        { title: 'Drug Wars', content: 'Lord that became a ring' },
        { title: 'Cheese Wars', content: 'Lord that became a ring' },
        { title: 'Dog Wars', content: 'Lord that became a ring' },
        { title: 'Dummy Wars', content: 'Lord that became a ring' },
        { title: 'Dummy of the Rings', content: 'Lord that became a ring' }
        ]
Article.create(data)
```

Migrate and populate the database.

```
rails db:migrate
rails db:seed
```

## Test Connectivity to ElasticSearch

Index the articles data in elasticsearch.

```
rake searchkick:reindex CLASS=Article
```

We can now play in the rails console to verify search functionality.

```
$ rails c
> results = Article.search('War')
  Article Search (11.7ms)  curl http://localhost:9200/articles_development/_search?pretty -d '{"query":{"dis_max":{"queries":[{"match":{"_all":{"query":"War","boost":10,"operator":"and","analyzer":"searchkick_search"}}},{"match":{"_all":{"query":"War","boost":10,"operator":"and","analyzer":"searchkick_search2"}}},{"match":{"_all":{"query":"War","boost":1,"operator":"and","analyzer":"searchkick_search","fuzziness":1,"prefix_length":0,"max_expansions":3,"fuzzy_transpositions":true}}},{"match":{"_all":{"query":"War","boost":1,"operator":"and","analyzer":"searchkick_search2","fuzziness":1,"prefix_length":0,"max_expansions":3,"fuzzy_transpositions":true}}}]}},"size":1000,"from":0,"fields":[]}'
 => #<Searchkick::Results:0x007fcf42475dd8 @klass=Article (call 'Article.connection' to establish a connection), @response={"took"=>9, "timed_out"=>false, "_shards"=>{"total"=>5, "successful"=>5, "failed"=>0}, "hits"=>{"total"=>6, "max_score"=>0.37037593, "hits"=>[{"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"16", "_score"=>0.37037593}, {"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"15", "_score"=>0.37037593}, {"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"12", "_score"=>0.3074455}, {"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"14", "_score"=>0.3074455}, {"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"1", "_score"=>0.21875}, {"_index"=>"articles_development_20160518103333170", "_type"=>"article", "_id"=>"13", "_score"=>0.21875}]}}, @options={:page=>1, :per_page=>1000, :padding=>0, :load=>true, :includes=>nil, :json=>false, :match_suffix=>"analyzed", :highlighted_fields=>[]}>
```

We are able to connect to the elasticsearch server using searchkick library and retrieve the search results.

```
> results.class
 => Searchkick::Results
```

The result is Searchkick::Results object. We have 6 records in the results.

``` 
> results.size
  Article Load (0.4ms)  SELECT "articles".* FROM "articles" WHERE "articles"."id" IN (16, 15, 12, 14, 1, 13)
 => 6
```

## Integrate Typeahead with Rails 5 App

```rhtml
<%= form_tag articles_path, method: :get do %>
  <%= text_field_tag :query, params[:query], class: 'form-control' %>
  <%= submit_tag 'Search' %>
<% end %>
```

You can now search in the articles index page. Download typeahead.js version 0.11.1 and move it to vendor/assets/javascripts directory. Include typeahead.js in the application.js.

```
//= require typeahead
```

Add the endpoint for the autocomplete suggestions in articles controller.

```
def autocomplete
  render json: Article.search(params[:query], autocomplete: true, limit: 10).map(&:title)
end
```

Declare the route for autocomplete.

```ruby
Rails.application.routes.draw do
  resources :articles do
    get :autocomplete
  end
end
```

Add id and autocomplete attributes to the search text field in articles index page.

```rhtml
<%= text_field_tag :query, params[:query], class: 'form-control', id: "article_search", autocomplete: "off" %>
```

Add the following javascript to articles.js.

```javascript
var ready;
ready = function() {
    var engine = new Bloodhound({
        datumTokenizer: function(d) {
            console.log(d);
            return Bloodhound.tokenizers.whitespace(d.title);
        },
        queryTokenizer: Bloodhound.tokenizers.whitespace,
        remote: {
            url: '../articles/autocomplete?query=%QUERY',
			wildcard: '%QUERY'
        }
    });
 
    var promise = engine.initialize();
 
    promise
        .done(function() { console.log('success!'); })
        .fail(function() { console.log('err!'); });
 
    $('.typeahead').typeahead(null, {
        name: 'engine',
        displayKey: 'title',
        source: engine.ttAdapter()
    });
}
 
$(document).ready(ready);
$(document).on('page:load', ready);
``` 

If you don't provide the wildcard, you will get the error:

```
GET http://localhost:3000/search/autocomplete?query=%QUERY 400 (Bad Request)
```

in the browser inspect window and in the log file:

```
HTTP parse error, malformed request puma
```

## Isolating Problems

You can use curl to isolate the problem to front-end or back-end issue.

```
curl http://localhost:3000/articles?query='dog'
```

In the log file, we see:

```
Article Search (19.4ms)  curl http://localhost:9200/articles_development/_search?pretty -d '{"query":{"dis_max":{"queries":[{"match":{"_all":{"query":"dog","boost":10,"operator":"and","analyzer":"searchkick_search"}}},{"match":{"_all":{"query":"dog","boost":10,"operator":"and","analyzer":"searchkick_search2"}}},{"match":{"_all":{"query":"dog","boost":1,"operator":"and","analyzer":"searchkick_search","fuzziness":1,"prefix_length":0,"max_expansions":3,"fuzzy_transpositions":true}}},{"match":{"_all":{"query":"dog","boost":1,"operator":"and","analyzer":"searchkick_search2","fuzziness":1,"prefix_length":0,"max_expansions":3,"fuzzy_transpositions":true}}}]}},"size":1000,"from":0,"fields":[]}'
  Rendering articles/index.html.erb within layouts/application
```

In the terminal output:

```
<!DOCTYPE html>
<html>
  <head>
    <title>Autoc</title>
    <meta name="csrf-param" content="authenticity_token" />
<meta name="csrf-token" content="O9rx6qf0ik6a2omrGp9Q4ZC/qDeITrQ+MUQKilWV+sitUtQgEmcQu5sbme/f3x1WPmlAVZXvUaccmA37n5/qLw==" />
    <link rel="stylesheet" media="all" href="/assets/articles.self-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.css?body=1" data-turbolinks-track="reload" />
<link rel="stylesheet" media="all" href="/assets/scaffolds.self-c8da12f732bc71ad84951b487f45ea012ee16be9a1df0d0de3b4bfa12f17deb4.css?body=1" data-turbolinks-track="reload" />
<link rel="stylesheet" media="all" href="/assets/application.self-af04b226fd7202dfc532ce7aedb95a0128277937e90d3b3a3d35e1cce9e16886.css?body=1" data-turbolinks-track="reload" />
    <script src="/assets/jquery.self-660adc51e0224b731d29f575a6f1ec167ba08ad06ed5deca4f1e8654c135bf4c.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/jquery_ujs.self-e87806d0cf4489aeb1bb7288016024e8de67fd18db693fe026fe3907581e53cd.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/typeahead.self-7d0ec0be4d31a26122c3f2780527cd624a8bcbd7350f5f5d6cb23a5a51f516ef.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/turbolinks.self-979a09514ef27c84df025c07108a05438ba97cfec71073dcb800a4d327044e02.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/articles.self-ca74ce155498e7f07e39291ec69ec2f10ec2ffff27a15d2539eff6e3a4dfbf02.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/action_cable.self-97a1acc11db2782c1b61ce874bff887f64e903d3cb2b533eff50fb799c873c70.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/cable.self-6e0514260c1aa76eaf252412ce74e63f68819fd19bf740595f592c5ba4c36537.js?body=1" data-turbolinks-track="reload"></script>
<script src="/assets/application.self-afe802b04eaf1de2ea762489c83c08aa4c4ff3ff13c21566e43cb710683f5abc.js?body=1" data-turbolinks-track="reload"></script>
  </head>
  <body>
    <p id="notice"></p>
<form action="/articles" accept-charset="UTF-8" method="get"><input name="utf8" type="hidden" value="&#x2713;" />
  <input type="text" name="query" id="article_search" value="dog" class="form-control" />
  <input type="submit" name="commit" value="Search" data-disable-with="Search" />
</form>
<h1>Articles</h1>
<table>
  <thead>
    <tr>
      <th>Title</th>
      <th>Content</th>
      <th colspan="3"></th>
    </tr>
  </thead>
  <tbody>
      <tr>
        <td>Dog Wars</td>
        <td>Lord that became a ring</td>
        <td><a href="/articles/15">Show</a></td>
        <td><a href="/articles/15/edit">Edit</a></td>
        <td><a data-confirm="Are you sure?" rel="nofollow" data-method="delete" href="/articles/15">Destroy</a></td>
      </tr>
      <tr>
        <td>Dog of the Rings</td>
        <td>Lord that became a ring</td>
        <td><a href="/articles/5">Show</a></td>
        <td><a href="/articles/5/edit">Edit</a></td>
        <td><a data-confirm="Are you sure?" rel="nofollow" data-method="delete" href="/articles/5">Destroy</a></td>
      </tr>
  </tbody>
</table>
<a href="/articles/new">New Article</a>
  </body>
</html>
```

This is without autocomplete. You will get the error:

```
ActiveRecord::RecordNotFound (Couldn't find Article with 'id'=autocomplete):
```

If you don't define the routes within the collection block in routes.rb. Check the output of rake routes:

```
article_autocomplete GET    /articles/:article_id/autocomplete(.:format) articles#autocomplete
```

The route is not correct. Let's fix it in routes.rb.

```ruby
Rails.application.routes.draw do
  resources :articles do
    collection do
      get :autocomplete
    end
  end
end
```

## Implement Autocomplete 

In article model configure autocomplete.

```
searchkick autocomplete: ['title']
```

Implement the autocomplete action in the articles controller.

```ruby
def autocomplete
  render json: Article.search(params[:query], autocomplete: false, limit: 10).map do |book|
    { title: book.title, value: book.id }
  end
end
```

You need to add the typeahead class to the search form.

```rhtml
<%= text_field_tag :query, params[:query], class: 'form-control typeahead' %>
```

You will now be able to see the autocomplete in action as you type the search term. 

## Style Autocomplete Dropdown

Let's now style the dropdown box in the autocomplete list. Create typeahead.scss and add:

```css
.tt-query {
  -webkit-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);
     -moz-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);
          box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);
}

.tt-hint {
  color: #999
}

.tt-menu {    /* used to be tt-dropdown-menu in older versions */
  width: 422px;
  margin-top: 4px;
  padding: 4px 0;
  background-color: #fff;
  border: 1px solid #ccc;
  border: 1px solid rgba(0, 0, 0, 0.2);
  -webkit-border-radius: 4px;
     -moz-border-radius: 4px;
          border-radius: 4px;
  -webkit-box-shadow: 0 5px 10px rgba(0,0,0,.2);
     -moz-box-shadow: 0 5px 10px rgba(0,0,0,.2);
          box-shadow: 0 5px 10px rgba(0,0,0,.2);
}

.tt-suggestion {
  padding: 3px 20px;
  line-height: 24px;
}

.tt-suggestion.tt-cursor,.tt-suggestion:hover {
  color: #fff;
  background-color: #0097cf;

}

.tt-suggestion p {
  margin: 0;
}
```

You will now see a nice looking dropdown for the autocomplete values. You can download the source code for this article from [autocomplete]( 'autocomplete').

## Summary

In this article, you learned how to use Typeahead javascript library to implement autocomplete for search feature using ElasticSearch and SearcKick in Rails 5 apps.

## References

[Add Search Functionality in Rails 4 App using ElasticSearch and Typeahead](https://sharvy.net/2015/01/12/add-robust-search-functionality-in-your-rails-4-app-using-elasticsearch-and-typeahead-js/ 'Add Search Functionality in Rails 4 App using ElasticSearch and Typeahead')
[Twitter Bootstrap Style Dropdown](https://github.com/bassjobsen/typeahead.js-bootstrap-css/blob/master/typeaheadjs.css 'Twitter Bootstrap Style Dropdown')
