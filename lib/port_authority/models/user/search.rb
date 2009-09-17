class User
  
  class Search
    
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 100
    
    attr_reader :page, :page_size
    
    def initialize(page, page_size, options, query)
      if (@page = page.to_i.abs) == 0
        @page = DEFAULT_PAGE
      end

      if (@page_size = page_size.to_i.abs) == 0
        @page_size = DEFAULT_PAGE_SIZE
      end
      
      @result_offset = (@page - 1) * @page_size

      @options = options.is_a?(Hash) ? options : {}
      @query = query
    end

    def users
      execute_search
      @users
    end
    
    def total_count
      execute_search
      @total_count
    end

    private
    
    def execute_search
      return if @search_executed
      
      @search_executed = true

      order = PortAuthority::default_user_sort || [:email.asc]
      counter_options = @options.dup
      filter_options = { :order => order, :offset => @result_offset, :limit => @page_size }.merge!(counter_options)

      if @query && !@query.blank?
        possible_user_ids = PortAuthority.is_searchable? ? full_text_search_with_ferret : full_text_search_with_sql

        if possible_user_ids.any?
          counter_options[:id] = possible_user_ids
          filter_options[:id] = possible_user_ids
        else
          # We've pre-filtered, and came back with 0 results.  There's no way applying additional
          # filters will return any more results, so fail fast.
          @total_count, @users = 0, []
          return false
        end
      end

      # The list of users representing the current page (@page)
      @users = User.all(filter_options)
      
      # The number total users that match the search query and options
      @total_count = User.count(counter_options)

      true
    end

    ##
    # Return a list of User ID's from ferret that match the query
    ##
    def full_text_search_with_ferret
      clean = @query.split(" ").collect { |q| "+*:#{q}*" }.join(" ")
      repository(:search).search("+_type:User #{clean}")[User]
    end

    ##
    # Return a list of User ID's from SQL that match the query
    ##
    def full_text_search_with_sql
      user_search_query = <<-SQL.margin
        SELECT id
        FROM users
        WHERE
          #{User.full_text_search_fields.map { |field_name| full_text_search_fragment(field_name) }.join(' OR ')}
      SQL

      parameters = ["%#{@query}%"] * User.full_text_search_fields.size
      repository(:default).adapter.query(user_search_query, *parameters)
    end

    def full_text_search_fragment(field_name)
      if User.repository.adapter.class.name =~ /postgres/i
        "#{field_name} ILIKE ?"
      else
        "#{field_name} LIKE ?"
      end
    end
    
  end
  
end