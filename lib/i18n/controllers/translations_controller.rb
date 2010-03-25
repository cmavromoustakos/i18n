class TranslationsController < ActionController::Base 
  def show 
    if request.post?

    end
    
    if request.get?
      
      # translation = Translation.find(:all)
      language = Language.find(params[:language])
      
      
      klass = params[:klass]
      attribute = params[:attribute]
      id = params[:id]
      
      
      object = klass.classify.constantize.find(id)
      
      translation = object.send(attribute.to_sym, :language => language)
      
      
      
      @posts = {
          :key => object,
          :language => language,
          :text => translation
          }
                
        respond_to do |format|
          format.xml { render :xml => @posts.to_xml(:root => 'translation') }
          format.json { render :json => @posts }
        end

    end

    if request.delete?
      # delete the resource
    end
    
  end
  
end 