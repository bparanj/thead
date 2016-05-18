class Article < ApplicationRecord
  searchkick autocomplete: ['title']
end
