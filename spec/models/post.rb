class Post
  include Elastictastic::Document

  field :title
  field :comments_count, :type => 'integer'
  field :tags, :index => 'analyzed' do
    field :non_analyzed, :index => 'not_analyzed'
  end
  field :created_at, :type => 'date'
  field :published_at, :type => 'date'

  embed :author, Author
  embed :comments, Comment
end
