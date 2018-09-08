require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    cols = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
    SQL

    cols.map!{ |el| el.to_sym }
    @columns = cols
  end


  def self.finalize!
    self.columns.each do |col|
      define_method(col) do
        @attributes[col]
      end

      define_method("#{col}=") do |value|
        self.attributes[col] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.underscore.pluralize
  end

  def self.all
    all = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    self.parse_all(all)
  end

  def self.parse_all(results)
    arr = []
    results.each do |result|
      arr << self.new(result)
    end
    arr
  end

  def self.find(id)
    find = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
    SQL

    return nil if find.count == 0
    self.parse_all(find).first
  end

  def initialize(params = {})
    params.each do |attr_name, val|
      attr_name = attr_name.to_sym
      if self.class.columns.include?(attr_name)
        self.send("#{attr_name}=", val)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end


  def attributes
    @attributes ||= {}
  end

  def attribute_values
    result = []
    self.attributes.each_value do |val|
      result << val
    end
    result
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.join(', ')
    question_marks = []
    columns.count.times do
      question_marks << "?"
    end
    question_marks = question_marks.join(', ')

    DBConnection.execute(<<-SQL, attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id

  end

  def update
    set_string = self.class.columns.drop(1).map{|el| "#{el} = ?"}.join(', ')

    DBConnection.execute(<<-SQL, attribute_values.drop(1))
      UPDATE
        #{self.class.table_name}
      SET
        #{set_string}
      WHERE
        id = #{self.id}
    SQL
  end

  def save
    begin
      id_exists = true unless id.nil?
    rescue
      id_exists = false
    end

    id_exists ? update : insert
  end
end
