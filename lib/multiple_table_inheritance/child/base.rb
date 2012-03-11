module MultipleTableInheritance
  module Child
    module Base
      def self.default_options
        { :dependent => :destroy, :inherit_methods => false }
      end
      
      def self.included(base)
        base.extend ClassMethods
        base.class_attribute :parent_association_name
      end
      
      module ClassMethods
        def inherits_from(association_name, options={})
          # Standardize options, and remove those that should not affect the belongs_to relationship
          options = Base::default_options.merge(options.to_options)
          inherit_methods = options.delete(:inherit_methods)
          
          extend FinderMethods, SharedMethods
          include InstanceMethods, SharedMethods
          include DelegateMethods if inherit_methods
          
          # Set association references.
          self.parent_association_name = association_name.to_sym
          self.primary_key = "#{parent_association_name}_id"
          
          # Ensure parent association is always returned.
          define_method("#{parent_association_name}_with_autobuild") do
            send("#{parent_association_name}_without_autobuild") || send("build_#{parent_association_name}")
          end
          
          # Allow getting and setting of parent attributes and relationships.
          inherited_columns_and_associations.each do |name|
            delegate name, "#{name}=", :to => parent_association_name
          end
          
          # Ensure parent's accessible attributes are accessible in child.
          parent_association_class.accessible_attributes.each do |attr|
            attr_accessible attr.to_sym
          end
          
          # Bind relationship, handle validation, and save properly.
          belongs_to parent_association_name, options
          alias_method_chain parent_association_name, :autobuild
          before_validation :set_association_subtype
          validate :parent_association_must_be_valid
          before_save :parent_association_must_be_saved
        end
        
        private
        
        def parent_association_class
          reflection = create_reflection(:belongs_to, parent_association_name, {}, self)
          reflection.klass
        end
        
        def inherited_columns_and_associations
          # Get the associated columns and relationship names
          inherited_columns = parent_association_class.column_names
          inherited_methods = parent_association_class.reflections.map { |key, value| key.to_s }
          
          # Filter out columns that the class already has
          # inherited_columns = inherited_columns.reject do |column|
          #   (self.column_names.grep(column).length > 0) || (column == 'type') || (column == parent_association_class.subtype_column)
          # end
          
          # Filter out methods that the class already has
          inherited_methods = inherited_methods.reject do |method|
            self.reflections.map { |key, value| key.to_s }.include?(method)
          end
          
          inherited_columns + inherited_methods - ['id']
        end
      end
      
      module FinderMethods
        def find_by_sql(*args)
          child_records = super(*args)
          
          child_records.each do |child|
            parent = parent_association_class.as_supertype.find_by_id(child.id)
            child.send(:parent_association=, parent)
          end
        end
      end
      
      module SharedMethods
        def find_by_id(*args)
          send("find_by_#{parent_association_name}_id", *args)
        end
      end
      
      module InstanceMethods
        private
        
        def parent_association
          send(self.class.parent_association_name)
        end
        
        def parent_association=(record)
          send("#{self.class.parent_association_name}=", record)
        end
        
        def set_association_subtype
          association = parent_association
          if association.attribute_names.include?(association.class.subtype_column)
            association[association.class.subtype_column] = self.class.to_s
          end
        end
        
        def parent_association_must_be_valid
          association = parent_association
          
          unless valid = association.valid?
            association.errors.each do |attr, message|
              errors.add(attr, message)
            end
          end
          
          valid
        end
        
        def parent_association_must_be_saved
          association = parent_association
          association.save(:validate => false)
          self.id = association.id
        end
      end
      
      module DelegateMethods
        private
        
        def method_missing(name, *args)
          if parent_association.respond_to?(name)
            parent_association.public_send(name, *args)
          else
            super(name, *args)
          end
        end
        
        def respond_to?(name)
          parent_association.respond_to?(name) || super
        end
      end
    end
  end
end
