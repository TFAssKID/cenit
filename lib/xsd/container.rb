module Xsd
  class Container < AttributedTag
    include BoundedTag

    attr_reader :elements

    def initialize(args)
      super
      @elements = []
    end

    def when_element_end(element)
      @elements << element
    end

    %w{sequence choice all}.each do |container_tag|
      class_eval("def #{container_tag}_start(attributes = [])
          Xsd::#{container_tag.capitalize}.new(parent: self, attributes: attributes)
        end
      def when_#{container_tag}_end(container)
        @elements << container
      end")
    end

    def any_start(attributes = [])
      @elements << Xsd::Any.new(parent: self, attributes: attributes)
      nil
    end

    def to_json_schema
      json = {'type' => 'object', 'title' => tag_name.capitalize}
      json['properties'] = properties = {}
      required = []
      if max_occurs == :unbounded || max_occurs > 0 || min_occurs > 1
        enum = 0
        elements.each do |element|
          element_schema = element.to_json_schema
          if element.max_occurs == :unbounded || element.max_occurs > 1 || element.min_occurs > 1
            plural_title = (element_schema['title'] || element.name || element.tag_name).to_title.pluralize
            properties[p = "property_#{enum += 1}"] = {'title' => "List of #{plural_title}",
                                                       'type' => 'array',
                                                       'minItems' => element.min_occurs,
                                                       'items' => element_schema}
            properties[p]['maxItems'] = element.max_occurs unless element.max_occurs == :unbounded
            required << p if element.min_occurs > 0
          elsif element.is_a?(Container)
            container_required = element_schema['required'] || []
            element_schema['properties'].each do |property, schema|
              properties[p = "property_#{enum += 1}"] = schema
              required << p if container_required.include?(property)
            end
          else
            properties[p = "property_#{enum += 1}"] = element_schema
          end
        end
      end
      json['required'] = required if required.present?
      json
    end
  end
end
