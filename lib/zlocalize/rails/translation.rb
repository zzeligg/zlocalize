class Translation < ActiveRecord::Base
   belongs_to :translated, :polymorphic => true
   
   def to_s
     return self.value
   end
   
end
