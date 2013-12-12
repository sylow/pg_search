require "active_record"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/strip"
require "pg_search/extensions/arel"

module PgSearch
  autoload :Compatibility, "pg_search/compatibility"
  autoload :Configuration, "pg_search/configuration"
  autoload :Document, "pg_search/document"
  autoload :Features, "pg_search/features"
  autoload :Multisearch, "pg_search/multisearch"
  autoload :Multisearchable, "pg_search/multisearchable"
  autoload :Normalizer, "pg_search/normalizer"
  autoload :ScopeOptions, "pg_search/scope_options"
  autoload :VERSION, "pg_search/version"

  mattr_accessor :multisearch_options
  self.multisearch_options = {}

  mattr_accessor :unaccent_function
  self.unaccent_function = "unaccent"

  def pg_search_scope(name, options)
    options_proc = if options.respond_to?(:call)
                     options
                   else
                     unless options.respond_to?(:merge)
                       raise ArgumentError, "pg_search_scope expects a Hash or Proc"
                     end
                     lambda { |query| {:query => query}.merge(options) }
                   end

    method_proc = lambda do |*args|
      config = Configuration.new(options_proc.call(*args), self)
      scope_options = ScopeOptions.new(config)
      scope_options.apply(self)
    end

    if respond_to?(:define_singleton_method)
      define_singleton_method name, &method_proc
    else
      (class << self; self; end).send :define_method, name, &method_proc
    end
  end

  def multisearchable(options = {})
    include PgSearch::Multisearchable
    class_attribute :pg_search_multisearchable_options
    self.pg_search_multisearchable_options = options
  end

  class << self
    def extended mod
      return if ActiveRecord::VERSION::MAJOR >= 4
      mod.send :include, Compatibility::ActiveRecord3
    end

    def included _
      raise 'extend PgSearch instead of including it'
    end

    def multisearch(*args)
      PgSearch::Document.search(*args)
    end

    def disable_multisearch
      Thread.current["PgSearch.enable_multisearch"] = false
      yield
    ensure
      Thread.current["PgSearch.enable_multisearch"] = true
    end

    def multisearch_enabled?
      if Thread.current.key?("PgSearch.enable_multisearch")
        Thread.current["PgSearch.enable_multisearch"]
      else
        true
      end
    end
  end

  class NotSupportedForPostgresqlVersion < StandardError; end
end

require "pg_search/railtie" if defined?(Rails)
