module Assignable
  def assign_ivar(arg)
    self.instance_var = arg
  end
end

class Something
  include Assignable
  
  attr_reader :instance_var
  
  def make_ivar_ivar
    instance_var = 'ivar'
  end
  
  private
  
  attr_writer :instance_var
end

some = Something.new

p some

some.assign_ivar('arg')

p some