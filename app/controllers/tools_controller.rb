class ToolsController < ApplicationController
  protect_from_forgery except: :webhook
  before_action :set_tool, only: %i[show edit update destroy update_translation]

  def index
    @tools = Tool.all
  end

  def show; end

  def new
    @tool = Tool.new
  end

  def create
    @tool = Tool.new(tool_params)

    respond_to do |format|
      if @tool.save
        format.html do
          # can be replaced with your username, repository name
          spec_data = GithubService.new('railstesh', 'coding_challenge').read_file(@tool.name, @tool.language)
          keys_data = LokaliseService.new('79f58e3b769ce941f75bab97d7fb17f118cf5524', '944415995ecebd933b7b96.13035535').create_keys(spec_data, @tool.language)
          @tool.update(json_spec: spec_data, key_info: keys_data)
          redirect_to @tool, notice: 'Tool created successfully'
        end
      else
        format.html { render :new }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @tool.update(tool_params)
        format.html do
          redirect_to @tool,
                      notice: 'Tool was successfully updated.'
        end
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    @tool.destroy

    redirect_to tools_path
  end

  def update_translation
    LokaliseJob.perform_later(@tool.id)
    redirect_to tools_path,
                notice: 'Updating process has initiated. It can take up to 5 minutes.'
  end

  # https://coding_challenge.ngrok.io/tools/webhook
  def webhook
    pr = params[:pull_request]
    if pr[:state].eql?('closed') && pr[:merged].eql?(true)
      # title will be like: tool-1-BMI.en.json | tool-<id>-<file_name>
      title = pr[:title]
      id = title.split('-')[1]
      file_name = title.sub(/.*-\d*-/, '')
      file_content = JSON.parse(File.read(file_name))
      tool = Tool.find(id)
      tool.update_attribute(:json_spec, file_content)

      render json: { status: 200 }
    end
  end

  private

  def tool_params
    params.require(:tool).permit(:name, :language, :json_spec)
  end

  def set_tool
    @tool = Tool.find(params[:id])
  end
end
